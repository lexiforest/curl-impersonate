FROM alpine:3.21 AS builder

WORKDIR /build

RUN apk update && \
    apk add git ninja cmake make patch linux-headers build-base libc-dev \
    ca-certificates curl

COPY . /build

# Single build: shared+static libcurl and static curl binary
RUN mkdir /build/install && \
    BUILD_ARGS="-DCMAKE_INSTALL_PREFIX=/build/install -DCURL_CA_PATH=/etc/ssl/certs -DCURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt" && \
    make prepare-libidn2 BUILD_DIR=build && \
    make build BUILD_DIR=build CMAKE_CONFIGURE_ARGS="$BUILD_ARGS" && \
    make checkbuild BUILD_DIR=build CMAKE_CONFIGURE_ARGS="$BUILD_ARGS" && \
    make install-strip BUILD_DIR=build CMAKE_CONFIGURE_ARGS="$BUILD_ARGS"


FROM alpine:3.21

RUN apk update && \
    apk add ca-certificates libstdc++ \
    && rm -rf /var/cache/apk/*

COPY --from=builder /build/install /usr/local

CMD ["curl-impersonate", "--version"]
