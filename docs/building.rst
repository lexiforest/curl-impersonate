Building from source
====================

This guide shows how to compile and install curl-impersonate and libcurl-impersonate from source.
The build process takes care of downloading dependencies, patching them, compiling them
and finally compiling curl itself with the needed patches.
There are currently three build options depending on your use case:

* Native build
* Cross compiling
* Docker container build

Unlike the upstream project, there is only one version in this fork for impersonating all main stream browsers.

Native build
------------

Ubuntu
~~~~~~

Install dependencies for building all the components:

.. code-block:: bash

    sudo apt-get install -y git ninja-build cmake autoconf automake pkg-config libtool \
    clang llvm lld libc++-dev libc++abi-dev \
    ca-certificates curl \
    curl zlib1g-dev libzstd-dev \
    golang-go bzip2 xz-utils unzip

Clone this repository:

.. code-block:: bash

    git clone https://github.com/lexiforest/curl-impersonate.git
    cd curl-impersonate

Configure and compile:

.. code-block:: bash

    mkdir build && cd build
    ../configure

    # Build and install
    make build
    sudo make install

    # You may need to update the linker's cache to find libcurl-impersonate
    sudo ldconfig

    # Optionally remove all the build files
    cd ../ && rm -Rf build

This will install curl-impersonate, libcurl-impersonate and the wrapper scripts to `/usr/local`.
To change the installation path, pass `--prefix=/path/to/install/` to the `configure` script.

After installation you can run the wrapper scripts, e.g.:

.. code-block:: bash

    curl_chrome119 https://www.wikipedia.org

    # or run directly with you own flags:
    curl-impersonate https://www.wikipedia.org

Red Hat based (CentOS/Fedora/Amazon Linux)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Install dependencies:

.. code-block:: bash

    yum groupinstall "Development Tools"
    yum groupinstall "C Development Tools and Libraries" # Fedora only
    yum install cmake3 python3 python3-pip
    # Install Ninja. This may depend on your system.
    yum install ninja-build
    # OR
    pip3 install ninja
    yum install zstd libzstd-devel
    yum install golang

You may need to follow the [Go installation instructions](https://go.dev/doc/install) if
it's not packaged for your system.

Then follow the 'Ubuntu' instructions for the actual build.

macOS
~~~~~~

Install dependencies for building all the components:

.. code-block:: bash

    brew install pkg-config make cmake ninja autoconf automake libtool
    brew install zstd
    brew install go

Clone this repository:

.. code-block:: bash

    git clone https://github.com/lexiforest/curl-impersonate.git
    cd curl-impersonate

Configure and compile:

.. code-block:: bash

    mkdir build && cd build
    ../configure
    # Build and install
    gmake build sudo gmake install
    # Optionally remove all the build files
    cd ../ && rm -Rf build

Static compilation
------------------

To compile curl-impersonate statically with libcurl-impersonate, pass `--enable-static`
to the `configure` script.

Cross compiling
---------------

We use the ``zig`` toolchain to provide various build targets, please use the
`github workflow <https://github.com/lexiforest/curl-impersonate/blob/main/.github/workflows/build-and-test.yml>`_
as a reference.


Docker build
------------

The Docker build is a bit more reproducible and serves as the reference implementation.
It creates a Debian-based and Alpine-based Docker images with the binaries.

`docker/debian.dockerfile <https://github.com/lexiforest/curl-impersonate/blob/main/docker/debian.dockerfile>`_
is a debian-based Dockerfile that will build curl with all the necessary modifications and patches.
Build it like the following:

.. code-block:: bash

    docker build -t curl-impersonate .

`docker/alpine.dockerfile <https://github.com/lexiforest/curl-impersonate/blob/main/docker/alpine.dockerfile>`_
is the Alpine-based version.

The resulting binaries and libraries are in the `/usr/local` directory, which contains:

- ``bin/curl-impersonate``, The curl binary that can impersonate Chrome/Edge/Safari/Firefox. It is compiled statically against libcurl, BoringSSL, and libnghttp2 so that it won't conflict with any existing libraries on your system. You can use it from the container or copy it out. Tested to work on Ubuntu 22.04.
- ``curl_chrome99``, ``curl_chrome100``, ``...`` - Wrapper scripts that launch `curl-impersonate` with all the needed flags.
- ``libcurl-impersonate.so``, ``libcurl-impersonate.so`` - libcurl compiled with impersonation support.

You can use them inside the docker, copy them out using `docker cp` or use them in a multi-stage docker build.

.. warning::

   Currently, curl-impersonate was built with LLVM's libc++, so the you may need to
   ``apt install libc++1 libc++abi1``.
   We plan to either build it statically or use glibc's libstdc++ in the future.
