#!/bin/bash

get_dep() {
	git clone $1 "$PWD/deps/$2"
	if [[ -n "$3" ]]; then
		git -C "$PWD/deps/$2" checkout "$3"
	fi
}

get_dep https://github.com/madler/zlib.git zlib $ZLIB_COMMIT
get_dep https://github.com/facebook/zstd.git zstd $ZSTD_COMMIT
get_dep https://github.com/google/brotli.git brotli $BROTLI_COMMIT
get_dep https://boringssl.googlesource.com/boringssl.git boringssl $BORINGSSL_COMMIT
get_dep https://github.com/curl/curl.git curl $CURL_TAG
get_dep https://github.com/nghttp2/nghttp2.git nghttp2 $NGHTTP2_COMMIT
get_dep https://github.com/ngtcp2/nghttp3.git nghttp3 $NGHTTP3_TAG
get_dep https://github.com/ngtcp2/ngtcp2.git ngtcp2 $NGTCP2_TAG
get_dep https://github.com/c-ares/c-ares.git c-ares $CARES_TAG

git -C "$PWD/deps/nghttp2" submodule update --init
git -C "$PWD/deps/nghttp3" submodule update --init
git -C "$PWD/deps/ngtcp2" submodule update --init

patch -p1 -d "$PWD/deps/boringssl" < "$PWD/patches/boringssl.patch"
patch -p1 -d "$PWD/deps/curl" < "$PWD/patches/curl.patch"
patch -p1 < "$PWD/win/deps.patch"
