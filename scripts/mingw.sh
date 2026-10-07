#!/bin/sh
set -eu

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <Make target> --toolchain=<toolchain> --arch=<architecture>" >&2
  exit 1
fi
ACTION=$1
shift

if [ -n "${MINGW_ROOT:-}" ]; then
  export PATH="$MINGW_ROOT/bin:$PATH"
fi

TOOLCHAIN="${MINGW_TOOLCHAIN:-}"
ARCH="${MINGW_ARCH:-}"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --toolchain=clang)
      TOOLCHAIN=clang ;;
    --toolchain=gcc)
      TOOLCHAIN=gcc ;;
    --toolchain=*)
      echo "Unknown toolchain: ${1#*=}" >&2
      exit 1 ;;
    --arch=x86_64|--arch=i686|--arch=aarch64|--arch=armv7)
      ARCH=${1#*=} ;;
    --arch=*)
      echo "Unknown architecture: ${1#*=}" >&2
      exit 1 ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1 ;;
  esac
  shift
done

if [ -z "$TOOLCHAIN" ]; then
  echo "Missing required option: --toolchain" >&2
  exit 1
fi
if [ -z "$ARCH" ]; then
  echo "Missing required option: --arch" >&2
  exit 1
fi

case "$TOOLCHAIN:$ARCH" in
  clang:x86_64|clang:i686|clang:aarch64|clang:armv7)
    _CC=clang _CXX=clang++ ;;
  gcc:x86_64|gcc:i686|gcc:aarch64)
    _CC=gcc _CXX=g++ ;;
  *)
    echo "Unsupported architecture '$ARCH' for $TOOLCHAIN" >&2
    exit 1 ;;
esac

CC="${MINGW_CC:-${ARCH}-w64-mingw32-${_CC}}"
CXX="${MINGW_CXX:-${ARCH}-w64-mingw32-${_CXX}}"

MAKE=${MAKE:-make}

USE_WINE="${USE_WINE:-0}"
CURL_RUNNER="${CURL_RUNNER:-}"
if [ "$USE_WINE" = "1" ] && [ -z "${CURL_RUNNER}" ]; then
  CURL_RUNNER="wine"
fi

BUILD_DIR=${BUILD_DIR:-build}

CMAKE_CONFIGURE_ARGS="${CMAKE_CONFIGURE_ARGS:-}"
CMAKE_CONFIGURE_ARGS="$CMAKE_CONFIGURE_ARGS -G Ninja -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_SYSTEM_PROCESSOR=$ARCH"
CMAKE_CONFIGURE_ARGS="$CMAKE_CONFIGURE_ARGS -DUSE_LIBIDN2=OFF -DCMAKE_ASM_NASM_COMPILER=nasm"
CMAKE_CONFIGURE_ARGS="$CMAKE_CONFIGURE_ARGS -DCMAKE_C_COMPILER=$CC -DCMAKE_CXX_COMPILER=$CXX"
CMAKE_BUILD_ARGS="${CMAKE_BUILD_ARGS:-}"
CMAKE_INSTALL_ARGS="${CMAKE_INSTALL_ARGS:-}"

$MAKE $ACTION BUILD_DIR="$BUILD_DIR" CMAKE="${CMAKE:-cmake}" TARGET="${TARGET:-curl-impersonate}" \
    CMAKE_CONFIGURE_ARGS="$CMAKE_CONFIGURE_ARGS" \
    CMAKE_BUILD_ARGS="${CMAKE_BUILD_ARGS:-}" CMAKE_INSTALL_ARGS="${CMAKE_INSTALL_ARGS:-}" JOBS="${JOBS:-}" \
    CURL_RUNNER="${CURL_RUNNER:-}" CURL_BIN="$BUILD_DIR/deps/build/curl/src/curl-impersonate.exe"
