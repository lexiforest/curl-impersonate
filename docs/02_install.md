## Installation
There are two versions of `curl-impersonate` for technical reasons. The **chrome** version is used to impersonate Chrome, Edge and Safari.

### Pre-compiled binaries
Pre-compiled binaries for Windows, Linux and macOS are available at the [GitHub releases](https://github.com/lexiforest/curl-impersonate/releases) page. Before you use them you may need to install zstd and CA certificates:

* Ubuntu - `sudo apt install ca-certificates zstd libzstd-dev`
* Red Hat/Fedora/CentOS - `yum install ca-certificates zstd libzstd-devel`
* Archlinux - `pacman -S ca-certificates zstd`
* macOS - `brew install ca-certificates zstd`

The pre-compiled binaries contain `libcurl-impersonate` and a statically compiled `curl-impersonate` for ease of use.

The pre-compiled Linux binaries are built for Ubuntu systems. On other distributions if you have errors with certificate verification you may have to tell curl where to find the CA certificates. For example:

    curl_chrome123 https://www.wikipedia.org --cacert /etc/ssl/certs/ca-bundle.crt

Also make sure to read [Notes on Dependencies](#notes-on-dependencies).

### Building from source

See [INSTALL.md](INSTALL.md).

### Docker images

> [!WARNING]
> New docker images added in this fork are work in progress.

Docker images based on Alpine Linux and Debian with `curl-impersonate` compiled and ready to use are available on [Docker Hub](https://hub.docker.com/r/lwthiker/curl-impersonate). The images contain the binary and all the wrapper scripts. Use like the following:

```bash
# Chrome version, Alpine Linux
docker pull lwthiker/curl-impersonate:0.5-chrome
docker run --rm lwthiker/curl-impersonate:0.5-chrome curl_chrome110 https://www.wikipedia.org
```

### Distro packages

> [!WARNING]
> This is for the upstream project

AUR packages are available to Archlinux users:
* Pre-compiled package: [curl-impersonate-bin](https://aur.archlinux.org/packages/curl-impersonate-bin), [libcurl-impersonate-bin](https://aur.archlinux.org/packages/libcurl-impersonate-bin).
* Build from source code: [curl-impersonate-chrome](https://aur.archlinux.org/packages/curl-impersonate-chrome)
