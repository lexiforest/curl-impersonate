FROM python:3.12-slim-bookworm AS builder

WORKDIR /build

RUN apt-get update && \
    apt-get install -y git ninja-build cmake autoconf automake pkg-config libtool \
    ca-certificates curl \
    golang-go bzip2 xz-utils unzip

COPY . /build

# Single build: shared+static libcurl and static curl binary
RUN mkdir /build/install && \
    BUILD_ARGS="-DCMAKE_INSTALL_PREFIX=/build/install -DCURL_CA_PATH=/etc/ssl/certs -DCURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt" && \
    make build BUILD_DIR=build CMAKE_CONFIGURE_ARGS="$BUILD_ARGS" && \
    make checkbuild BUILD_DIR=build CMAKE_CONFIGURE_ARGS="$BUILD_ARGS" && \
    make install-strip BUILD_DIR=build CMAKE_CONFIGURE_ARGS="$BUILD_ARGS"


FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y ca-certificates libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/install /usr/local

# Update the loader's cache
RUN ldconfig

CMD ["curl-impersonate", "--version"]
