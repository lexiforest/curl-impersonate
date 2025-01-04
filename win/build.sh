#!/bin/bash

set -ex

mkdir -p build/
cd build/

# Download and patch boringssl

BORING_SSL_COMMIT=cd95210465496ac2337b313cf49f607762abe286
curl -L https://github.com/google/boringssl/archive/${BORING_SSL_COMMIT}.zip -o boringssl.zip
unzip -q -o boringssl.zip
mv boringssl-${BORING_SSL_COMMIT} boringssl

cd boringssl

patchfile=../../patches/boringssl.patch
patch -p1 < $patchfile
sed -i 's/-ggdb//g' CMakeLists.txt
sed -i 's/-Werror//g' CMakeLists.txt

cmake -G "Ninja" -S . -B lib -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=gcc.exe -DOPENSSL_NO_ASM=1
ninja -C lib crypto ssl
mv lib/crypto/libcrypto.a lib/libcrypto.a
mv lib/ssl/libssl.a lib/libssl.a

cd ..

export BROTLI_LIBS='-lbrotlidec -lbrotlicommon'
export OPENSSL_PATH=$PWD/boringssl
export OPENSSL_LIBPATH=$PWD/boringssl/lib

CURL_VERSION=curl-8_11_0

curl -L https://github.com/curl/curl/archive/${CURL_VERSION}.zip -o curl.zip
unzip -q -o curl.zip
mv curl-${CURL_VERSION} curl

# Apparently, building curl on windows has changes since this commit:
# https://github.com/curl/curl/commit/a8861b6ccdd7ca35b6115588a578e36d765c9e38

cd curl

patchfile=../../patches/curl.patch
patch -p1 < $patchfile

export CMAKE_PREFIX_PATH=../boringssl
export CFLAGS='-Wno-unused-variable -static -static-libgcc -static-libstdc++'
export CXXFLAGS='-static -static-libgcc -static-libstdc++'
export LDFLAGS='-static -static-libgcc -static-libstdc++ -lz -lidn2 -lnghttp2 -lbrotlidec -lpsl'

cmake -B build -G "MinGW Makefiles" \
    -DENABLE_IPV6=ON \
    -DENABLE_UNICODE=ON \
    -DUSE_NGHTTP2=ON \
    -DUSE_LIBIDN2=ON \
    -DENABLE_WEBSOCKETS=ON \
    -DCURL_BROTLI=ON \
    -DCURL_ZLIB=ON \
    -DCURL_ZSTD=ON \
    -DENABLE_IPV6=ON \
    -DCURL_ENABLE_SSL=ON \
    -DCURL_USE_OPENSSL=ON \
    -DCURL_USE_LIBSSH2=OFF \
    -DCURL_USE_LIBSSH=OFF \
    -DUSE_ECH=ON \
    -DHAVE_ECH=ON \
    -DUSE_HTTPSRR \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_STATIC_LIBS=ON \
    -DBUILD_STATIC_CURL=ON \


cd build

mingw32-make clean
mingw32-make -j CFG=-ssl-zlib-nghttp2-idn2-brotli-zstd-ipv6

cd ..

SYS=$1

mkdir -p ../dist
ls build
mv build/lib/libcurl* ../dist/
cp /$SYS/bin/libidn2-0.dll ../dist/
cp /$SYS/bin/libnghttp2-14.dll ../dist/
cp /$SYS/bin/libbrotlidec.dll ../dist/
cp /$SYS/bin/libbrotlicommon.dll ../dist/
cp /$SYS/bin/libpsl-5.dll ../dist/
cp /$SYS/bin/libssh2-1.dll ../dist/
cp /$SYS/bin/libzstd.dll ../dist/
cp /$SYS/bin/zlib1.dll ../dist/
cp /$SYS/bin/libiconv-2.dll ../dist/
cp /$SYS/bin/libintl-8.dll ../dist/
cp /$SYS/bin/libunistring-5.dll ../dist
cp /$SYS/bin/libgcc_s_dw2-1.dll ../dist | true  # 32bit
cp /$SYS/bin/libgcc_s_seh-1.dll ../dist | true  # 64bit
cp /$SYS/bin/libwinpthread-1.dll ../dist
cp /$SYS/bin//libstdc++-6.dll ../dist
mv build/src/*.exe ../dist/

cd ..
dist/curl.exe -V
