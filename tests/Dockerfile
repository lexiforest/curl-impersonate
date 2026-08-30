ARG CHROME_IMAGE=curl-impersonate

FROM ${CHROME_IMAGE} as chrome

FROM golang:1.24-bookworm AS socks5-builder

RUN GOBIN=/out CGO_ENABLED=0 \
    go install github.com/wzshiming/socks5/cmd/socks5@v0.7.0

FROM python:3.11-slim-bookworm

WORKDIR /tests

RUN apt-get update && \
    apt-get install -y tcpdump libbrotli1 gcc libcurl4-openssl-dev nghttp2-server git

COPY requirements.txt requirements.txt

RUN pip install --upgrade pip && \
    pip install -r requirements.txt

# Copy the built binaries from both containers
COPY --from=chrome /usr/local/ /usr/local/
COPY --from=socks5-builder /out/socks5 /usr/local/bin/socks5

# Needed to update the loader's cache
RUN ldconfig

COPY . .

# Compile 'minicurl' which is used for testing libcurl-impersonate.
# 'minicurl' is compiled against the "regular" libcurl.
# libcurl-impersonate will replace it at runtime via LD_PRELOAD.
RUN gcc -Wall -Werror -o minicurl minicurl.c `curl-config --libs`
RUN install minicurl /usr/local/bin

ENTRYPOINT ["pytest"]
