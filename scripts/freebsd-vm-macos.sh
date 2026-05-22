#!/bin/sh
set -eu

FREEBSD_RELEASE=${FREEBSD_RELEASE:-14.3}
VM_NAME=${VM_NAME:-curl-impersonate-freebsd}
VM_DIR=${VM_DIR:-.freebsd-vm}
VM_ARCH=${VM_ARCH:-host}
VM_CPUS=${VM_CPUS:-4}
VM_MEM=${VM_MEM:-8192}
VM_DISK_SIZE=${VM_DISK_SIZE:-40G}
SSH_PORT=${SSH_PORT:-2222}
VM_USER=${VM_USER:-builder}
BUILD_DIR=${BUILD_DIR:-build-freebsd}
INSTALL_DIR=${INSTALL_DIR:-freebsd-install}
REMOTE_DIR=${REMOTE_DIR:-/home/${VM_USER}/curl-impersonate}
LOCAL_ARTIFACTS_DIR=${LOCAL_ARTIFACTS_DIR:-${VM_DIR}/artifacts}

root_dir=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
vm_dir_abs=$root_dir/$VM_DIR
downloads_dir=$vm_dir_abs/downloads
seed_dir=$vm_dir_abs/seed
seed_iso=$vm_dir_abs/seed.iso
ssh_key=$vm_dir_abs/id_ed25519
pid_file=$vm_dir_abs/qemu.pid
serial_log=$vm_dir_abs/serial.log

usage() {
  cat <<EOF
Usage: $0 <command>

Commands:
  setup          Download image, create disk, key, and cloud-init seed ISO.
  start          Start the VM in the background.
  stop           Stop the VM.
  status         Show VM process and SSH status.
  wait           Wait until SSH is ready.
  ssh            Open an SSH shell.
  build          Sync this repo into the VM and run the FreeBSD build.
  fetch-artifacts Copy VM build artifacts into ${LOCAL_ARTIFACTS_DIR}.
  check-artifacts <path>
                 Copy local GitHub artifacts into the VM and run make checkbuild.

Environment overrides:
  FREEBSD_RELEASE=${FREEBSD_RELEASE}
  VM_DIR=${VM_DIR}
  VM_ARCH=${VM_ARCH} # host, aarch64, or amd64
  VM_CPUS=${VM_CPUS}
  VM_MEM=${VM_MEM}
  VM_DISK_SIZE=${VM_DISK_SIZE}
  SSH_PORT=${SSH_PORT}
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

need_macos() {
  [ "$(uname -s)" = "Darwin" ] || die "this helper is intended for macOS"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

host_arch() {
  case "$(uname -m)" in
    arm64|aarch64) echo aarch64 ;;
    x86_64|amd64) echo amd64 ;;
    *) die "unsupported host architecture: $(uname -m)" ;;
  esac
}

vm_arch() {
  case "$VM_ARCH" in
    host) host_arch ;;
    arm64|aarch64) echo aarch64 ;;
    x86_64|amd64) echo amd64 ;;
    *) die "unsupported VM_ARCH: $VM_ARCH" ;;
  esac
}

qemu_system() {
  case "$(vm_arch)" in
    aarch64) echo qemu-system-aarch64 ;;
    amd64) echo qemu-system-x86_64 ;;
  esac
}

image_url() {
  case "$(vm_arch)" in
    aarch64)
      echo "https://download.freebsd.org/releases/VM-IMAGES/${FREEBSD_RELEASE}-RELEASE/aarch64/Latest/FreeBSD-${FREEBSD_RELEASE}-RELEASE-arm64-aarch64-BASIC-CLOUDINIT-ufs.qcow2.xz"
      ;;
    amd64)
      echo "https://download.freebsd.org/releases/VM-IMAGES/${FREEBSD_RELEASE}-RELEASE/amd64/Latest/FreeBSD-${FREEBSD_RELEASE}-RELEASE-amd64-BASIC-CLOUDINIT-ufs.qcow2.xz"
      ;;
  esac
}

image_archive() {
  basename "$(image_url)"
}

base_image() {
  echo "$vm_dir_abs/freebsd-$(vm_arch)-base.qcow2"
}

disk_image() {
  echo "$vm_dir_abs/freebsd-$(vm_arch).qcow2"
}

qemu_share_dir() {
  if command -v brew >/dev/null 2>&1; then
    brew --prefix qemu 2>/dev/null | sed 's|$|/share/qemu|'
  fi
}

find_aarch64_efi() {
  for path in \
    "$(qemu_share_dir)/edk2-aarch64-code.fd" \
    /opt/homebrew/share/qemu/edk2-aarch64-code.fd \
    /usr/local/share/qemu/edk2-aarch64-code.fd
  do
    [ -n "$path" ] || continue
    [ -f "$path" ] && echo "$path" && return 0
  done
  return 1
}

ensure_qemu() {
  if command -v "$(qemu_system)" >/dev/null 2>&1 && command -v qemu-img >/dev/null 2>&1; then
    return
  fi
  if command -v brew >/dev/null 2>&1; then
    echo "Installing qemu with Homebrew..."
    brew install qemu
    return
  fi
  die "install qemu first, for example: brew install qemu"
}

ensure_key() {
  if [ ! -f "$ssh_key" ]; then
    mkdir -p "$vm_dir_abs"
    ssh-keygen -t ed25519 -N "" -f "$ssh_key" -C "${VM_NAME}" >/dev/null
  fi
}

make_seed_iso() {
  need_cmd hdiutil
  mkdir -p "$seed_dir"
  pubkey=$(cat "$ssh_key.pub")

  cat > "$seed_dir/meta-data" <<EOF
instance-id: ${VM_NAME}
local-hostname: ${VM_NAME}
EOF

  cat > "$seed_dir/user-data" <<EOF
#cloud-config
users:
  - name: ${VM_USER}
    gecos: FreeBSD Builder
    groups: wheel
    shell: /bin/sh
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ${pubkey}
ssh_pwauth: false
disable_root: true
growpart:
  mode: auto
package_update: true
packages:
  - pkgconf
  - cmake
  - ninja
  - curl
  - autoconf
  - automake
  - libtool
  - gmake
  - gperf
  - go
  - rsync
runcmd:
  - sysrc sshd_enable=YES
  - service sshd restart
EOF

  rm -f "$seed_iso"
  hdiutil makehybrid -iso -joliet -default-volume-name CIDATA \
    -o "$seed_iso" "$seed_dir" >/dev/null
}

setup_vm() {
  need_macos
  ensure_qemu
  need_cmd curl
  need_cmd xz
  ensure_key
  mkdir -p "$downloads_dir"

  archive=$downloads_dir/$(image_archive)
  if [ ! -f "$archive" ]; then
    curl -L "$(image_url)" -o "$archive"
  fi
  if [ ! -f "$(base_image)" ]; then
    xz -dc "$archive" > "$(base_image)"
  fi
  if [ ! -f "$(disk_image)" ]; then
    qemu-img create -f qcow2 -F qcow2 -b "$(base_image)" "$(disk_image)" "$VM_DISK_SIZE" >/dev/null
  fi
  make_seed_iso
  echo "FreeBSD VM prepared in $vm_dir_abs"
}

is_running() {
  [ -f "$pid_file" ] || return 1
  pid=$(cat "$pid_file")
  kill -0 "$pid" >/dev/null 2>&1
}

start_vm() {
  need_macos
  ensure_qemu
  [ -f "$(disk_image)" ] || setup_vm
  if is_running; then
    echo "VM already running with PID $(cat "$pid_file")"
    return
  fi

  mkdir -p "$vm_dir_abs"
  qemu=$(qemu_system)
  arch=$(vm_arch)
  if [ "$arch" = "$(host_arch)" ]; then
    accel=hvf
    cpu=host
  else
    accel=tcg
    cpu=max
    echo "Using QEMU emulation for ${arch}; this is much slower than native ${arch} virtualization."
  fi

  if [ "$arch" = "aarch64" ]; then
    efi=$(find_aarch64_efi) || die "missing AArch64 EFI firmware from qemu"
    "$qemu" \
      -name "$VM_NAME" \
      -machine "virt,accel=$accel" \
      -cpu "$cpu" \
      -smp "$VM_CPUS" \
      -m "$VM_MEM" \
      -bios "$efi" \
      -drive "file=$(disk_image),if=virtio,format=qcow2" \
      -drive "file=$seed_iso,if=virtio,media=cdrom,readonly=on" \
      -netdev "user,id=net0,hostfwd=tcp:127.0.0.1:${SSH_PORT}-:22" \
      -device virtio-net-device,netdev=net0 \
      -serial "file:$serial_log" \
      -display none \
      -daemonize \
      -pidfile "$pid_file"
  else
    "$qemu" \
      -name "$VM_NAME" \
      -machine "q35,accel=$accel" \
      -cpu "$cpu" \
      -smp "$VM_CPUS" \
      -m "$VM_MEM" \
      -drive "file=$(disk_image),if=virtio,format=qcow2" \
      -drive "file=$seed_iso,if=virtio,media=cdrom,readonly=on" \
      -netdev "user,id=net0,hostfwd=tcp:127.0.0.1:${SSH_PORT}-:22" \
      -device virtio-net-pci,netdev=net0 \
      -serial "file:$serial_log" \
      -display none \
      -daemonize \
      -pidfile "$pid_file"
  fi

  echo "VM started with PID $(cat "$pid_file")"
  echo "SSH: ssh -i $ssh_key -p $SSH_PORT ${VM_USER}@127.0.0.1"
}

ssh_opts() {
  echo "-i $ssh_key -p $SSH_PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=$vm_dir_abs/known_hosts"
}

wait_vm() {
  start_vm
  echo "Waiting for SSH on 127.0.0.1:$SSH_PORT..."
  n=0
  while [ "$n" -lt 180 ]; do
    if ssh $(ssh_opts) "${VM_USER}@127.0.0.1" "true" >/dev/null 2>&1; then
      echo "VM is ready"
      return
    fi
    n=$((n + 1))
    sleep 2
  done
  die "timed out waiting for SSH; see $serial_log"
}

stop_vm() {
  if ! is_running; then
    echo "VM is not running"
    rm -f "$pid_file"
    return
  fi
  ssh $(ssh_opts) "${VM_USER}@127.0.0.1" "sudo shutdown -p now" >/dev/null 2>&1 || kill "$(cat "$pid_file")"
  rm -f "$pid_file"
  echo "VM stopped"
}

status_vm() {
  if is_running; then
    echo "VM running with PID $(cat "$pid_file")"
  else
    echo "VM not running"
  fi
  if ssh $(ssh_opts) "${VM_USER}@127.0.0.1" "freebsd-version && uname -a" 2>/dev/null; then
    :
  else
    echo "SSH not ready"
  fi
}

sync_repo() {
  wait_vm
  need_cmd rsync
  ssh $(ssh_opts) "${VM_USER}@127.0.0.1" "mkdir -p '$REMOTE_DIR'"
  rsync -az --delete \
    --exclude .git \
    --exclude "$VM_DIR" \
    --exclude build \
    --exclude build-freebsd \
    -e "ssh $(ssh_opts)" \
    "$root_dir/" "${VM_USER}@127.0.0.1:$REMOTE_DIR/"
}

build_in_vm() {
  sync_repo
  ssh $(ssh_opts) "${VM_USER}@127.0.0.1" "cd '$REMOTE_DIR' && set -e
    install_dir=\$PWD/${INSTALL_DIR}
    rm -rf '${BUILD_DIR}' \"\$install_dir\" freebsd-artifacts
    mkdir -p \"\$install_dir\" freebsd-artifacts
    cmake_args='-G Ninja -DCMAKE_INSTALL_PREFIX='\$install_dir' -DUSE_LIBIDN2=OFF'
    gmake configure BUILD_DIR='${BUILD_DIR}' CMAKE_CONFIGURE_ARGS=\"\$cmake_args\"
    gmake build BUILD_DIR='${BUILD_DIR}' CMAKE_CONFIGURE_ARGS=\"\$cmake_args\"
    v=\"\$(${BUILD_DIR}/deps/build/curl/src/curl-impersonate -V)\"
    echo \"\$v\"
    echo \"\$v\" | grep -q zlib
    echo \"\$v\" | grep -q zstd
    echo \"\$v\" | grep -q brotli
    echo \"\$v\" | grep -q nghttp2
    echo \"\$v\" | grep -q BoringSSL
    gmake install-strip BUILD_DIR='${BUILD_DIR}' CMAKE_CONFIGURE_ARGS=\"\$cmake_args\""
}

fetch_artifacts() {
  wait_vm
  mkdir -p "$root_dir/$LOCAL_ARTIFACTS_DIR"
  rsync -az -e "ssh $(ssh_opts)" \
    "${VM_USER}@127.0.0.1:$REMOTE_DIR/${INSTALL_DIR}/" \
    "$root_dir/$LOCAL_ARTIFACTS_DIR/install/"
  echo "Artifacts copied to $root_dir/$LOCAL_ARTIFACTS_DIR"
}

prepare_local_artifacts() {
  artifacts_path=$1
  [ -e "$artifacts_path" ] || die "artifact path does not exist: $artifacts_path"

  case "$artifacts_path" in
    *.zip)
      need_cmd unzip
      expanded_dir=$vm_dir_abs/local-github-artifacts
      rm -rf "$expanded_dir"
      mkdir -p "$expanded_dir"
      unzip -q "$artifacts_path" -d "$expanded_dir"
      echo "$expanded_dir"
      ;;
    *)
      echo "$artifacts_path"
      ;;
  esac
}

check_artifacts_in_vm() {
  [ "$#" -eq 1 ] || die "usage: $0 check-artifacts <artifact-file-or-directory>"

  local_artifacts=$(prepare_local_artifacts "$1")
  sync_repo

  remote_artifacts="$REMOTE_DIR/github-artifacts"
  remote_check_dir="$REMOTE_DIR/github-artifact-check"
  ssh $(ssh_opts) "${VM_USER}@127.0.0.1" "rm -rf '$remote_artifacts' '$remote_check_dir' && mkdir -p '$remote_artifacts' '$remote_check_dir'"

  if [ -d "$local_artifacts" ]; then
    rsync -az -e "ssh $(ssh_opts)" \
      "$local_artifacts/" "${VM_USER}@127.0.0.1:$remote_artifacts/"
  else
    rsync -az -e "ssh $(ssh_opts)" \
      "$local_artifacts" "${VM_USER}@127.0.0.1:$remote_artifacts/"
  fi

  ssh $(ssh_opts) "${VM_USER}@127.0.0.1" "cd '$REMOTE_DIR' && set -e
    artifact=\$(find '$remote_artifacts' -type f -name 'curl-impersonate*.tar.gz' ! -name 'libcurl-*' | sort | head -n 1)
    if [ -n \"\$artifact\" ]; then
      tar -xzf \"\$artifact\" -C '$remote_check_dir'
    fi

    curl_bin=\$(find '$remote_check_dir' '$remote_artifacts' -type f -name curl-impersonate | sort | head -n 1)
    if [ -z \"\$curl_bin\" ]; then
      echo 'No curl-impersonate binary found in artifacts.' >&2
      find '$remote_artifacts' -maxdepth 3 -type f -print >&2
      exit 1
    fi

    chmod +x \"\$curl_bin\"
    gmake checkbuild CURL_BIN=\"\$curl_bin\""
}

case "${1:-}" in
  setup) setup_vm ;;
  start) start_vm ;;
  stop) stop_vm ;;
  status) status_vm ;;
  wait) wait_vm ;;
  ssh) wait_vm; exec ssh $(ssh_opts) "${VM_USER}@127.0.0.1" ;;
  build) build_in_vm ;;
  fetch-artifacts) fetch_artifacts ;;
  check-artifacts) shift; check_artifacts_in_vm "$@" ;;
  ""|-h|--help|help) usage ;;
  *) usage >&2; exit 2 ;;
esac
