FROM alpine:3.21 AS builder

WORKDIR /build

RUN apk update && \
    apk add git ninja cmake make patch linux-headers autoconf automake pkgconfig libtool \
    clang llvm lld libc-dev libc++-dev \
    llvm-libunwind llvm-libunwind-static xz-libs xz-dev xz-static \
    ca-certificates curl bash \
    python3 python3-dev \
    go bzip2 xz unzip

COPY . /build

ENV CC=clang CXX=clang++

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


FROM alpine:3.21

RUN apk update && \
    apk add ca-certificates libc++ \
    && rm -rf /var/cache/apk/*

COPY --from=builder /build/install /usr/local

# Replace /usr/bin/env bash with /usr/bin/env ash
RUN sed -i 's@/usr/bin/env bash@/usr/bin/env ash@' /usr/local/bin/curl_*

CMD ["curl-impersonate", "--version"]
