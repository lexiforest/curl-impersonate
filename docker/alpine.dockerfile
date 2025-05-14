FROM alpine:3.21 as builder

WORKDIR /build

RUN apk update && \
    apk add git ninja bash make cmake build-base patch linux-headers python3 python3-dev \
    autoconf automake pkgconfig libtool \
    curl \
    zlib-dev zstd-dev  \
    go unzip

COPY . /build

ENV CC=clang CXX=clang++


# Copy libcurl-impersonate and symbolic links
RUN cp -d /build/install/lib/libcurl-impersonate* /build/out

RUN ver=$(readlink -f ${CURL_VERSION}/lib/.libs/libcurl-impersonate.so | sed 's/.*so\.//') && \
    major=$(echo -n $ver | cut -d'.' -f1) && \
    ln -s "libcurl-impersonate.so.$ver" "out/libcurl-impersonate.so.$ver" && \
    ln -s "libcurl-impersonate.so.$ver" "out/libcurl-impersonate.so" && \
    strip "out/libcurl-impersonate.so.$ver"

# Verify that the resulting 'libcurl' is really statically compiled against its
# dependencies.
RUN ! (ldd ./out/curl-impersonate | grep -q -e nghttp2 -e brotli -e ssl -e crypto)

# Wrapper scripts
# Replace /usr/bin/env bash with /usr/bin/env ash
RUN chmod +x out/curl_*

FROM alpine:3.21

COPY --from=builder /build/install /usr/local

RUN sed -i 's@/usr/bin/env bash@/usr/bin/env ash@' out/curl_*
