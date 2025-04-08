# Building and installing curl-impersonate

This guide shows how to compile and install curl-impersonate and libcurl-impersonate from source.
The build process takes care of downloading dependencies, patching them, compiling them and finally compiling curl itself with the needed patches.
There are currently three build options depending on your use case:

* [Native build](#native-build) using an autotools-based Makefile
* [Cross compiling](#cross-compiling) using an autotools-based Makefile
* [Docker container build](#docker-build)

Unlike the upstream project, there is only one version in this fork, namely the Chrome version, for impersonating all main stream browsers.

## Native build

### Ubuntu

Install dependencies for building all the components:

```sh
sudo apt install build-essential pkg-config cmake ninja-build curl autoconf automake libtool
sudo apt install golang-go unzip
sudo apt install zstd libzstd-dev
```

Clone this repository:

```sh
git clone https://github.com/lexiforest/curl-impersonate.git
cd curl-impersonate
```

Configure and compile:

```sh
mkdir build && cd build
../configure
# Build and install
make build
sudo make install
# You may need to update the linker's cache to find libcurl-impersonate
sudo ldconfig
# Optionally remove all the build files
cd ../ && rm -Rf build
```

This will install curl-impersonate, libcurl-impersonate and the wrapper scripts to `/usr/local`. To change the installation path, pass `--prefix=/path/to/install/` to the `configure` script.

After installation you can run the wrapper scripts, e.g.:

```sh
curl_chrome119 https://www.wikipedia.org
```

or run directly with you own flags:

```sh
curl-impersonate https://www.wikipedia.org
```

### Red Hat based (CentOS/Fedora/Amazon Linux)

Install dependencies:

```sh
yum groupinstall "Development Tools"
yum groupinstall "C Development Tools and Libraries" # Fedora only
yum install cmake3 python3 python3-pip
# Install Ninja. This may depend on your system.
yum install ninja-build
# OR
pip3 install ninja
yum install zstd libzstd-devel
```

For the Chrome version, install Go.
You may need to follow the [Go installation instructions](https://go.dev/doc/install) if it's not packaged for your system:

```sh
yum install golang
```

Then follow the 'Ubuntu' instructions for the actual build.

### macOS

Install dependencies for building all the components:

```sh
brew install pkg-config make cmake ninja autoconf automake libtool
brew install zstd
brew install go
```

Clone this repository:

```sh
git clone https://github.com/lexiforest/curl-impersonate.git
cd curl-impersonate
```

Configure and compile:

```sh
mkdir build && cd build
../configure
# Build and install
gmake build
sudo gmake install
# Optionally remove all the build files
cd ../ && rm -Rf build
```

### Static compilation

To compile curl-impersonate statically with libcurl-impersonate, pass `--enable-static` to the `configure` script.


## Cross compiling

There is some basic support for cross compiling curl-impersonate.
It is currently being used to build curl-impersonate for ARM64 (aarch64) systems from x86-64 systems.
Cross compiling is similar to the usual build but a bit trickier:

* You'd have to build zlib and zstd for the target architecture so that curl can link with it.
* Some paths have to be specified manually since curl's own build system can't determine their location.

An example build for aarch64 on Ubuntu x86_64:

```sh
sudo apt-get install gcc-aarch64-linux-gnu g++-aarch64-linux-gnu

./configure --host=aarch64-linux-gnu \
            --with-zlib=/path/to/compiled/zlib \
            --with-zstd=/path/to/compiled/zstd \
            --with-ca-path=/etc/ssl/certs \
            --with-ca-bundle=/etc/ssl/certs/ca-certificates.crt

make build
```

The flags mean as follows:
`--with-zlib/zstd` is the location of a compiled zlib/zstd library for the target architecture.
`--with-ca-path` and `--with-ca-bundle` will be passed to curl's configure script as is.

## Docker build

The Docker build is a bit more reproducible and serves as the reference implementation. It creates a Debian-based Docker image with the binaries.

[`chrome/Dockerfile`](chrome/Dockerfile) is a debian-based Dockerfile that will build curl with all the necessary modifications and patches. Build it like the following:

```sh
docker build -t curl-impersonate chrome/
```

The resulting binaries and libraries are in the `/usr/local` directory, which contains:

* `curl-impersonate`, - The curl binary that can impersonate Chrome/Edge/Safari. It is compiled statically against libcurl, BoringSSL, and libnghttp2 so that it won't conflict with any existing libraries on your system. You can use it from the container or copy it out. Tested to work on Ubuntu 20.04.
* `curl_chrome99`, `curl_chrome100`, `...` - Wrapper scripts that launch `curl-impersonate` with all the needed flags.
* `libcurl-impersonate.so`, `libcurl-impersonate.so` - libcurl compiled with impersonation support. See [libcurl-impersonate](README.md#libcurl-impersonate) for more details.

You can use them inside the docker, copy them out using `docker cp` or use them in a multi-stage docker build.
