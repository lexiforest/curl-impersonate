FROM python:3.12-slim-bookworm as builder

WORKDIR /build

RUN apt-get update && \
    apt-get install -y git ninja-build cmake autoconf automake pkg-config libtool \
    clang llvm lld libc++-dev libc++abi-dev \
    ca-certificates \
    curl zlib1g-dev libzstd-dev \
    golang-go bzip2 xz-utils unzip

COPY . /build

ENV CC=clang CXX=clang++ 

# static build for curl-impersonate and libcurl-impersonate.a
RUN mkdir /build/install && \
    ./configure --prefix=/build/install \
        --enable-static \
        --with-zlib --with-zstd \
        --with-ca-path=/etc/ssl/certs \
        --with-ca-bundle=/etc/ssl/certs/ca-certificates.crt && \
    make build && \
    make checkbuild && \
    make install

# dynamic build for curl-impersonate and libcurl-impersonate.a
RUN mkdir /build/install && \
    ./configure --prefix=/build/install \
        --enable-static \
        --with-zlib --with-zstd \
        --with-ca-path=/etc/ssl/certs \
        --with-ca-bundle=/etc/ssl/certs/ca-certificates.crt && \
    make build && \
    make checkbuild && \
    make install

# # Copy libcurl-impersonate and symbolic links
# RUN cp -d /build/install/lib/libcurl-impersonate* /build/out
#
# RUN ver=$(readlink -f ${CURL_VERSION}/lib/.libs/libcurl-impersonate.so | sed 's/.*so\.//') && \
#     major=$(echo -n $ver | cut -d'.' -f1) && \
#     ln -s "libcurl-impersonate.so.$ver" "out/libcurl-impersonate.so.$ver" && \
#     ln -s "libcurl-impersonate.so.$ver" "out/libcurl-impersonate.so" && \
#     strip "out/libcurl-impersonate.so.$ver"
#
# # Verify that the resulting 'libcurl' is really statically compiled against its
# # dependencies.
# RUN ! (ldd ./out/curl-impersonate | grep -q -e nghttp2 -e brotli -e ssl -e crypto)



# FROM debian:bookworm-slim
# RUN apt-get update && apt-get install -y ca-certificates \
#     && rm -rf /var/lib/apt/lists/*

# Copy curl-impersonate from the builder image
# COPY --from=builder /build/install /usr/local
# Update the loader's cache
# RUN ldconfig

# Wrapper scripts
# COPY bin/*  /usr/local/bin
# RUN chmod +x out/curl_*
# COPY --from=builder /build/out/curl_* 
