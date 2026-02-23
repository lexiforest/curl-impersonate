FROM alpine:3.21 AS builder

WORKDIR /build

RUN apk update && \
    apk add git ninja cmake make patch linux-headers autoconf automake pkgconfig libtool \
    build-base libc-dev \
    xz-libs xz-dev xz-static \
    ca-certificates curl bash \
    python3 python3-dev \
    go bzip2 xz unzip

COPY . /build

# Single build: shared+static libcurl and static curl binary
RUN mkdir /build/install && \
    BUILD_ARGS="-DCMAKE_INSTALL_PREFIX=/build/install -DCURL_CA_PATH=/etc/ssl/certs -DCURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt" && \
    make build BUILD_DIR=build CMAKE_CONFIGURE_ARGS="$BUILD_ARGS" && \
    make checkbuild BUILD_DIR=build CMAKE_CONFIGURE_ARGS="$BUILD_ARGS" && \
    make install-strip BUILD_DIR=build CMAKE_CONFIGURE_ARGS="$BUILD_ARGS"


FROM alpine:3.21

RUN apk update && \
    apk add ca-certificates libstdc++ \
    && rm -rf /var/cache/apk/*

COPY --from=builder /build/install /usr/local

# Replace /usr/bin/env bash with /usr/bin/env ash
RUN sed -i 's@/usr/bin/env bash@/usr/bin/env ash@' /usr/local/bin/curl_*

CMD ["curl-impersonate", "--version"]
