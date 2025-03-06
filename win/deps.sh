#!/bin/bash

get_dep() {
	git clone $1 "$PWD/deps/$2"
	if [[ -n "$3" && "$3" =~ ^[0-9a-f]{40}$ ]]; then
		git -C "$PWD/deps/$2" checkout "$3"
	fi
}

get_dep https://github.com/madler/zlib.git zlib $ZLIB_COMMIT
get_dep https://github.com/facebook/zstd.git zstd $ZSTD_COMMIT
get_dep https://github.com/google/brotli.git brotli $BROTLI_COMMIT
get_dep https://boringssl.googlesource.com/boringssl.git boringssl $BORINGSSL_COMMIT
get_dep https://github.com/curl/curl.git curl $CURL_COMMIT
get_dep https://github.com/nghttp2/nghttp2.git nghttp2 $NGHTTP2_COMMIT

git -C "$PWD/deps/nghttp2" submodule update --init

patch -p1 -d "$PWD/deps/boringssl" < "$PWD/chrome/patches/boringssl.patch"
patch -p1 -d "$PWD/deps/curl" < "$PWD/chrome/patches/curl-impersonate.patch"
patch -p1 < "$PWD/win/deps.patch"
