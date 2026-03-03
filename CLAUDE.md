# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

curl-impersonate is a modified build of curl that can impersonate TLS and HTTP/2 signatures of major browsers (Chrome, Edge, Safari, Firefox, Tor). It patches curl + BoringSSL + several HTTP libraries so that the resulting binary's network fingerprints are identical to real browsers. This is the more active fork at `lexiforest/curl-impersonate`.

A single binary (`curl-impersonate`) supports all browsers. Browser-specific wrapper scripts in `bin/` invoke it with the right flags.

## Build Commands

Dependencies (Ubuntu):
```sh
sudo apt install build-essential pkg-config cmake ninja-build curl autoconf automake libtool golang-go unzip zstd libzstd-dev
```

Dependencies (macOS):
```sh
brew install pkg-config make cmake ninja autoconf automake libtool zstd go
```

Build (native):
```sh
mkdir build && cd build
../configure            # --enable-static for static build
make build              # downloads, patches, and compiles all deps + curl
make checkbuild         # verify required features are compiled in
sudo make install       # installs to /usr/local (or --prefix path)
```

On macOS, use `gmake` instead of `make`.

```sh
make clean              # removes ALL build artifacts including downloaded deps
```

Docker:
```sh
docker build -t curl-impersonate -f docker/debian.dockerfile docker/
docker build -t curl-impersonate:alpine -f docker/alpine.dockerfile docker/
```

## Testing

Tests use pytest and verify TLS/HTTP2 signatures match real browsers via packet capture. They require root/sudo for tcpdump.

```sh
pip3 install -r tests/requirements.txt
# Run from the tests/ directory
cd tests && sudo python3 -m pytest --log-cli-level DEBUG --install-dir /path/to/install --capture-interface eth0
```

Docker-based testing:
```sh
docker build -t curl-impersonate-tests tests/
docker run --rm curl-impersonate-tests
```

## Architecture

### Build Pipeline (Makefile.in)

The Makefile downloads, patches, and statically compiles all dependencies in order:
1. **zlib** (1.3.1), **zstd** (1.5.6) - compression
2. **brotli** (1.2.0) - compression, patched via `patches/brotli.patch`
3. **BoringSSL** (pinned commit) - TLS library, patched via `patches/boringssl.patch`
4. **nghttp2** (1.63.0) - HTTP/2 (pinned to <=1.64 because priority flag was removed in 1.65)
5. **ngtcp2** (1.20.0) + **nghttp3** (1.15.0) - QUIC/HTTP3, patched
6. **libunistring** + **libidn2** - IDN support (Linux only; macOS uses AppleIDN)
7. **curl** (8.15.0) - patched via `patches/curl.patch`, then configured and compiled

All deps are built as static libraries. The `configure.ac` / `configure` script handles cross-compilation via `--host=<triple>`.

### Key Patches (patches/)

- **curl.patch** (~331KB): The core modification. Adds `--impersonate` flag, custom TLS extension ordering, HTTP/2 settings/pseudo-header control, ECH support, certificate compression, GREASE handling, and the `curl_easy_impersonate()` libcurl API.
- **boringssl.patch** (~54KB): Tweaks BoringSSL to match browser TLS behavior (cipher suites, EC curves including X25519Kyber768/X25519MLKEM, extension permutation).
- **ngtcp2.patch**, **nghttp3.patch**: QUIC/HTTP3 fingerprint support.
- **brotli.patch**: Build system fix for cross-compilation.

### Wrapper Scripts (bin/)

Each `bin/curl_<browser>` script invokes `curl-impersonate` with browser-specific flags. Modern scripts (Chrome 131+) use the `--impersonate` flag directly. Older scripts pass explicit `--ciphers`, `-H` headers, `--curves`, `--http2-settings`, etc.

### Custom curl Options Added by This Project

CLI flags: `--impersonate`, `--cert-compression`, `--http2-pseudo-headers-order`, `--http2-settings`, `--tls-grease`, `--tls-extension-order`, `--alps`

libcurl API: `curl_easy_impersonate(handle, target, default_headers)` plus `CURLOPT_HTTPBASEHEADER`, `CURLOPT_HTTP2_PSEUDO_HEADERS_ORDER`, `CURLOPT_HTTP2_SETTINGS`, `CURLOPT_HTTP2_WINDOW_UPDATE`, `CURLOPT_SSL_ENABLE_ALPS`, `CURLOPT_SSL_SIG_HASH_ALGS`, `CURLOPT_SSL_CERT_COMPRESSION`, `CURLOPT_SSL_ENABLE_TICKET`, `CURLOPT_SSL_PERMUTE_EXTENSIONS`, `CURLOPT_TLS_GREASE`, `CURLOPT_TLS_EXTENSION_ORDER`

### Cross-Compilation

Extensive cross-compilation support via Zig toolchain shims (`zigshim/`). CI builds for: x86_64, i386, aarch64, arm, riscv64, loongarch64 (Linux); Intel/ARM (macOS); arm64 (iOS/Android); x86_64-musl.

### Test Signatures (tests/signatures/)

YAML database of known browser TLS Client Hello and HTTP/2 signatures. Tests capture network traffic and compare against these references.

### Windows Build

Separate build system in `win/` using `build.bat` and Visual Studio. Windows wrapper scripts are `.bat` files in `win/bin/`.
