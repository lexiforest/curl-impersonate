FROM python:3.12-slim-bookworm AS builder

WORKDIR /build

RUN apt-get update && \
    apt-get install -y git ninja-build cmake autoconf automake pkg-config libtool \
    ca-certificates curl \
    curl \
    golang-go bzip2 xz-utils unzip

COPY . /build

# dynamic build
RUN mkdir /build/install && \
    ./configure --prefix=/build/install \
        --with-ca-path=/etc/ssl/certs \
        --with-ca-bundle=/etc/ssl/certs/ca-certificates.crt && \
    make build && \
    make checkbuild && \
    make install

# static build
RUN ./configure --prefix=/build/install \
        --enable-static \
        --with-ca-path=/etc/ssl/certs \
        --with-ca-bundle=/etc/ssl/certs/ca-certificates.crt && \
    make build && \
    make checkbuild && \
    make install


FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y ca-certificates libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/install /usr/local

# Update the loader's cache
RUN ldconfig

CMD ["curl-impersonate", "--version"]
