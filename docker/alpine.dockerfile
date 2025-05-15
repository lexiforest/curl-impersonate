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


FROM alpine:3.21

RUN apt-get update && \
    apt-get install -y ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/install /usr/local

RUN ldconfig

# Replace /usr/bin/env bash with /usr/bin/env ash
RUN sed -i 's@/usr/bin/env bash@/usr/bin/env ash@' out/curl_*

CMD ["curl", "--version"]
