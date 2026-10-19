#!/bin/sh
set -eu

usage() {
  printf 'Usage: %s <make-target> --toolchain=<toolchain> --arch=<architecture>\n' "$0"
  cat <<'EOF'

Toolchains: clang, gcc
Architectures: x86_64, i686, aarch64; armv7 requires clang.
Examples of make targets: configure, build, checkbuild, install, clean.

Environment overrides:
  MINGW_TOOLCHAIN, MINGW_ARCH  Defaults for --toolchain and --arch.
  MINGW_ROOT                 Toolchain directory; adds its bin directory to PATH.
  MINGW_CC, MINGW_CXX         Override the target-prefixed compiler names.
  MAKE, CMAKE                Build tool executables (default: make, cmake).
  MAKEFLAGS                 Additional make options.
  BUILD_DIR                 Default: build/mingw-<toolchain>-<architecture>.
  TARGET                    CMake target for the 'target' make target.
  JOBS                      Parallel build jobs.
  CMAKE_CONFIGURE_ARGS       Additional CMake configure arguments.
  CMAKE_BUILD_ARGS           Additional CMake build arguments.
  CMAKE_INSTALL_ARGS         Additional CMake install arguments for install-strip.
  CURL_RUNNER               Command used to run the Windows binary for checkbuild.
  USE_WINE=1                Use wine when CURL_RUNNER is unset.

Relative paths are resolved from the repository root.
Use -h or --help to display this help.
EOF
}

if [ "$#" -lt 1 ]; then
  usage >&2
  exit 1
fi
case "$1" in
  -h|--help)
    usage
    exit 0 ;;
esac
action=$1
shift

toolchain=${MINGW_TOOLCHAIN:-}
arch=${MINGW_ARCH:-}
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0 ;;
    --toolchain=*)
      toolchain=${1#*=} ;;
    --arch=*)
      arch=${1#*=} ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1 ;;
  esac
  shift
done

if [ -z "$toolchain" ]; then
  echo "Missing required option: --toolchain" >&2
  exit 1
fi
if [ -z "$arch" ]; then
  echo "Missing required option: --arch" >&2
  exit 1
fi

case "$toolchain" in
  clang)
    cc=clang
    cxx=clang++ ;;
  gcc)
    cc=gcc
    cxx=g++ ;;
  *)
    echo "Unknown toolchain: $toolchain" >&2
    exit 1 ;;
esac
case "$arch" in
  x86_64|i686|aarch64|armv7) ;;
  *)
    echo "Unknown architecture: $arch" >&2
    exit 1 ;;
esac
if [ "$toolchain:$arch" = "gcc:armv7" ]; then
  echo "Unsupported architecture '$arch' for $toolchain" >&2
  exit 1
fi

root_dir=$(CDPATH='' cd "$(dirname "$0")/.." && pwd)
cd "$root_dir"
if [ -n "${MINGW_ROOT:-}" ]; then
  export PATH="$MINGW_ROOT/bin:$PATH"
fi

cc=${MINGW_CC:-${arch}-w64-mingw32-${cc}}
cxx=${MINGW_CXX:-${arch}-w64-mingw32-${cxx}}
make_cmd=${MAKE:-make}

curl_runner=${CURL_RUNNER:-}
if [ "${USE_WINE:-0}" = "1" ] && [ -z "$curl_runner" ]; then
  curl_runner=wine
fi

build_dir=${BUILD_DIR:-build/mingw-$toolchain-$arch}

cmake_configure_args=${CMAKE_CONFIGURE_ARGS:-}
cmake_configure_args="$cmake_configure_args -G Ninja -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_SYSTEM_PROCESSOR=$arch"
cmake_configure_args="$cmake_configure_args -DUSE_LIBIDN2=OFF -DCMAKE_ASM_NASM_COMPILER=nasm"
cmake_configure_args="$cmake_configure_args -DCMAKE_C_COMPILER=$cc -DCMAKE_CXX_COMPILER=$cxx"

"$make_cmd" "$action" \
  BUILD_DIR="$build_dir" \
  CMAKE="${CMAKE:-cmake}" \
  TARGET="${TARGET:-curl-impersonate}" \
  CMAKE_CONFIGURE_ARGS="$cmake_configure_args" \
  CMAKE_BUILD_ARGS="${CMAKE_BUILD_ARGS:-}" \
  CMAKE_INSTALL_ARGS="${CMAKE_INSTALL_ARGS:-}" \
  JOBS="${JOBS:-}" \
  CURL_RUNNER="$curl_runner" \
  CURL_BIN="$build_dir/deps/build/curl/src/curl-impersonate.exe"
