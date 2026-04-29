Building from source
====================

This guide explains how to build and install curl-impersonate and libcurl-impersonate
from source. The build process downloads the dependencies, applies the required patches,
builds the dependencies, and finally builds curl itself.

There are currently three build paths, depending on your use case:

* Native build
* Cross compiling
* Docker container build

Unlike the upstream project, this fork uses a single build for all major browser
profiles, including both webkit and firefox variants.

Native build
------------

Ubuntu
~~~~~~

Install the dependencies required to build all components:

.. code-block:: bash

    sudo apt-get install -y \
        git ninja-build cmake autoconf automake pkg-config libtool \
        ca-certificates curl \
        curl \
        golang-go bzip2 xz-utils unzip

Clone this repository:

.. code-block:: bash

    git clone https://github.com/lexiforest/curl-impersonate.git
    cd curl-impersonate

Configure and build:

.. code-block:: bash

    mkdir build && cd build

    # Optionally, use --enable-static for static binaries
    ../configure

    # Build and install
    make build
    sudo make install

    # You may need to update the linker's cache to find libcurl-impersonate
    sudo ldconfig

    # Optionally remove all the build files
    cd ../ && rm -Rf build

This installs curl-impersonate, libcurl-impersonate, and the wrapper scripts to
``/usr/local``. To change the installation path, pass
``--prefix=/path/to/install/`` to ``configure``.

After installation, you can run the wrapper scripts, for example:

.. code-block:: bash

    curl_chrome119 https://www.example.com

    # Or run the binary directly with your own flags:
    curl-impersonate https://www.example.com

Red Hat based (CentOS/Fedora/Amazon Linux)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Install the required dependencies:

.. code-block:: bash

    yum groupinstall "Development Tools"
    yum groupinstall "C Development Tools and Libraries" # Fedora only
    yum install cmake3 python3 python3-pip
    # Install Ninja. This may depend on your system.
    yum install ninja-build
    # OR
    pip3 install ninja
    yum install golang

You may need to follow the `Go installation instructions <https://go.dev/doc/install>`_
if your distribution does not package it.

Then follow the Ubuntu instructions for the actual build.

macOS
~~~~~~

Install the dependencies required to build all components:

.. code-block:: bash

    brew install pkg-config make cmake ninja autoconf automake libtool
    brew install go

Clone this repository:

.. code-block:: bash

    git clone https://github.com/lexiforest/curl-impersonate.git
    cd curl-impersonate

Configure and build:

.. code-block:: bash

    mkdir build && cd build
    ../configure
    # Build and install
    gmake build sudo gmake install
    # Optionally remove all the build files
    cd ../ && rm -Rf build

Static compilation
------------------

To compile curl-impersonate statically with libcurl-impersonate, pass ``--enable-static``
to the ``configure`` script.

Cross compiling
---------------

We use the ``zig`` toolchain for cross-compilation targets. Use the
`GitHub workflow <https://github.com/lexiforest/curl-impersonate/blob/main/.github/workflows/build-and-test.yml>`_
as a reference.


Docker build
------------

The Docker build is more reproducible and serves as the reference implementation. It
produces both Debian-based and Alpine-based images containing the built binaries.

`docker/debian.dockerfile <https://github.com/lexiforest/curl-impersonate/blob/main/docker/debian.dockerfile>`_
is the Debian-based Dockerfile used to build curl with all required modifications and
patches. Build it like this:

.. code-block:: bash

    docker build -t curl-impersonate .

`docker/alpine.dockerfile <https://github.com/lexiforest/curl-impersonate/blob/main/docker/alpine.dockerfile>`_
is the Alpine-based variant.

The resulting binaries and libraries are placed in ``/usr/local`` and include:

* ``bin/curl-impersonate``: the curl binary that can impersonate
  Chrome/Edge/Safari/Firefox. It is linked statically against libcurl, BoringSSL, and
  libnghttp2 so it does not conflict with existing libraries on your system. You can run
  it inside the container or copy it out. It has been tested on Ubuntu 22.04.
* ``curl_chrome99``, ``curl_chrome100``, ``...``: wrapper scripts that launch
  ``curl-impersonate`` with the required flags.
* ``libcurl-impersonate.so``: libcurl built with impersonation support.

You can use these files inside the container, copy them out with ``docker cp``, or use
them in a multi-stage Docker build.

