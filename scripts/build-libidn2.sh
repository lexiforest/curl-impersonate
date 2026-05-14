#!/bin/sh
set -eu

build_dir=${BUILD_DIR:-build}
root_dir=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
case "$build_dir" in
  /*) ;;
  *) build_dir="$root_dir/$build_dir" ;;
esac
install_dir="$build_dir/deps/install"
src_dir="$build_dir/deps/src"
build_deps_dir="$build_dir/deps/build"
downloads_dir="$build_dir/deps/downloads"

libunistring_version=${LIBUNISTRING_VERSION:-1.1}
libunistring_url=${LIBUNISTRING_URL:-https://ftp.gnu.org/gnu/libunistring/libunistring-$libunistring_version.tar.gz}
libidn2_version=${LIBIDN2_VERSION:-2.3.7}
libidn2_url=${LIBIDN2_URL:-https://ftp.gnu.org/gnu/libidn/libidn2-$libidn2_version.tar.gz}

case "${PREPARE_LIBIDN2:-auto}:${CMAKE_CONFIGURE_ARGS:-}" in
  off:*|OFF:*|0:*|false:*|FALSE:*|no:*|NO:*|*:*-DUSE_LIBIDN2=OFF*|*:*-DUSE_LIBIDN2=FALSE*|*:*-DUSE_LIBIDN2=0*)
    echo "Skipping libidn2 preparation"
    exit 0
    ;;
  *:*-DUSE_LIBIDN2=ON*|*:*-DUSE_LIBIDN2=TRUE*|*:*-DUSE_LIBIDN2=1*)
    ;;
  auto:*-DCMAKE_SYSTEM_NAME=Android*|auto:*-DCMAKE_SYSTEM_NAME=iOS*|auto:*-DCMAKE_SYSTEM_NAME=Windows*)
    echo "Skipping libidn2 preparation"
    exit 0
    ;;
  auto:*)
    if [ "$(uname -s)" = Darwin ]; then
      echo "Skipping libidn2 preparation"
      exit 0
    fi
    ;;
esac

make_cmd=${MAKE:-make}
if command -v gmake >/dev/null 2>&1; then
  make_cmd=${MAKE:-gmake}
fi
make_jobs=
if [ -n "${JOBS:-}" ]; then
  make_jobs="-j$JOBS"
fi

host_arg=
if [ -n "${ZIG_FLAGS:-}" ]; then
  set -- $ZIG_FLAGS
  while [ "$#" -gt 0 ]; do
    if [ "$1" = "-target" ] && [ "$#" -gt 1 ]; then
      target=${2%%.[0-9]*}
      host_arg="--host=$target"
      break
    fi
    shift
  done
fi

mkdir -p "$downloads_dir" "$src_dir" "$build_deps_dir" "$install_dir"

included_unistring_marker="$install_dir/.libidn2-included-unistring"
if [ ! -f "$install_dir/lib/libidn2.a" ] || [ ! -f "$included_unistring_marker" ]; then
  archive="$downloads_dir/libidn2-$libidn2_version.tar.gz"
  [ -f "$archive" ] || curl -L "$libidn2_url" -o "$archive"
  rm -rf "$src_dir/libidn2" "$build_deps_dir/libidn2"
  mkdir -p "$src_dir/libidn2" "$build_deps_dir/libidn2"
  tar -xf "$archive" -C "$src_dir/libidn2" --strip-components=1
  cd "$build_deps_dir/libidn2"
  PKG_CONFIG_PATH="$install_dir/lib/pkgconfig" \
    "$src_dir/libidn2/configure" \
      --prefix="$install_dir" \
      --disable-shared \
      --enable-static \
      --with-pic \
      --disable-nls \
      --with-included-libunistring \
      $host_arg
  "$make_cmd" MAKEFLAGS="$make_jobs"
  "$make_cmd" install MAKEFLAGS=
  touch "$included_unistring_marker"
fi
