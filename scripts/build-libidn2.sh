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

libidn2_version="2.3.7"
libidn2_sha256="4c21a791b610b9519b9d0e12b8097bf2f359b12f8dd92647611a929e6bfd7d64"
libidn2_urls="https://ftpmirror.gnu.org/gnu/libidn/libidn2-$libidn2_version.tar.gz https://ftp.gnu.org/gnu/libidn/libidn2-$libidn2_version.tar.gz"

make_cmd=${MAKE:-make}
if command -v gmake >/dev/null 2>&1; then
  make_cmd=${MAKE:-gmake}
fi
make_jobs=
if [ -n "${JOBS:-}" ]; then
  make_jobs="-j$JOBS"
fi

sha256sum_cmd=sha256sum
if command -v sha256 >/dev/null 2>&1; then
  sha256sum_cmd=sha256
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
  verified=
  [ -f "$archive" ] || for libidn2_url in $libidn2_urls; do
    if curl -fL "$libidn2_url" -o "$archive" && \
        printf "%s  %s\n" "$libidn2_sha256" "$archive" | $sha256sum_cmd -c -; then
      verified=1
      break
    fi
  done
  [ -n "$verified" ] || printf "%s  %s\n" "$libidn2_sha256" "$archive" | $sha256sum_cmd -c -
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
