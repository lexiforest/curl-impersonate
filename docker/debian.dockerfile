FROM python:3.12-slim-bookworm as builder

WORKDIR /build

RUN apt-get update && \
    apt-get install -y git ninja-build cmake autoconf automake pkg-config libtool \
    clang llvm lld libc++-dev libc++abi-dev \
    ca-certificates curl \
    curl zlib1g-dev libzstd-dev \
    golang-go bzip2 xz-utils unzip

COPY . /build

ENV CC=clang CXX=clang++

# dynamic build
RUN mkdir /build/install && \
    ./configure --prefix=/build/install \
        --with-zlib --with-zstd \
        --with-ca-path=/etc/ssl/certs \
        --with-ca-bundle=/etc/ssl/certs/ca-certificates.crt && \
    make build && \
    make checkbuild && \
    make install

# static build
RUN ./configure --prefix=/build/install \
        --enable-static \
        --with-zlib --with-zstd \
        --with-ca-path=/etc/ssl/certs \
        --with-ca-bundle=/etc/ssl/certs/ca-certificates.crt && \
    make build && \
    make checkbuild && \
    make install


FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/install /usr/local

# Update the loader's cache
RUN ldconfig

CMD ["curl", "--version"]
