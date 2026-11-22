FROM debian:bookworm-slim AS builder

WORKDIR /build

RUN apt-get update && \
    apt-get install -y git gcc g++ binutils patch make ninja-build \
    cmake ca-certificates curl

COPY . /build

# Single build: shared+static libcurl and static curl binary
RUN mkdir /build/install && \
    BUILD_ARGS="-DCMAKE_INSTALL_PREFIX=/build/install -DCURL_CA_PATH=/etc/ssl/certs -DCURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt" && \
    make prepare-libidn2 BUILD_DIR=build && \
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
