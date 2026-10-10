Building from source
====================

This guide explains how to build and install curl-impersonate and libcurl-impersonate
from source. The build process downloads the dependencies, applies the required patches,
builds the dependencies, and finally builds curl itself.

There are currently four build paths, depending on your use case:

* Native build
* Cross compiling
* FreeBSD VM build
* Docker container build

Unlike the upstream project, this fork uses a single build for all major browser
profiles, including both webkit and firefox variants.

Native build
------------

Linux
~~~~~

Install the dependencies
^^^^^^^^^^^^^^^^^^^^^^^^

Ubuntu:

.. code-block:: bash

    sudo apt install -y \
        git gcc g++ binutils patch make cmake ninja-build ca-certificates curl

Red Hat based (CentOS Stream, Fedora, Amazon Linux, AlmaLinux, Rocky Linux, etc.):

.. code-block:: bash

    sudo dnf install -y \
        git gcc gcc-c++ binutils patch make cmake curl

    # Install Ninja. This may depend on your system.
    sudo dnf install -y ninja-build
    # OR
    sudo dnf install -y python3 python3-pip
    pip3 install ninja

Clone the repository
^^^^^^^^^^^^^^^^^^^^

.. code-block:: bash

    git clone https://github.com/lexiforest/curl-impersonate.git
    cd curl-impersonate

Configure and build
^^^^^^^^^^^^^^^^^^^

.. code-block:: bash

    make prepare-libidn2

    # Static linking with libcurl is enabled by default
    make configure

    # Build and install
    make build
    sudo make install

    # You may need to update the linker's cache to find libcurl-impersonate
    sudo ldconfig

    # Optionally remove all the build files
    rm -Rf build

This installs curl-impersonate, libcurl-impersonate, and the wrapper scripts to
``/usr/local``. To change the installation path, pass
``CMAKE_CONFIGURE_ARGS="-DCMAKE_INSTALL_PREFIX=/path/to/install/"`` to
``make configure``.

After installation, you can run the wrapper scripts, for example:

.. code-block:: bash

    curl_chrome119 https://www.example.com

    # Or run the binary directly with your own flags:
    curl-impersonate https://www.example.com

macOS
~~~~~~

Install the dependencies
^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: bash

    brew install make cmake ninja

Clone the repository
^^^^^^^^^^^^^^^^^^^^

.. code-block:: bash

    git clone https://github.com/lexiforest/curl-impersonate.git
    cd curl-impersonate

Configure and build
^^^^^^^^^^^^^^^^^^^

.. code-block:: bash

    gmake configure
    # Build and install
    gmake build
    sudo gmake install
    # Optionally remove all the build files
    rm -Rf build

macOS static release dependencies
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The macOS release workflow uses curl's pkg-config metadata to derive the system
libraries and frameworks required by the merged ``libcurl-impersonate.a``. It
publishes a relocatable ``libcurl-impersonate.pc`` beside the archive and embeds
the same system dependencies as Mach-O linker options in an archive member.

Existing Apple linker consumers using ``-Wl,-force_load,<archive>`` receive these
options without querying pkg-config themselves. The metadata member must be
loaded and automatic linking must be enabled. Ordinary selective archive links
can query ``pkg-config --static`` using the extracted release directory, but
``--static`` only adds private dependencies. Replace ``-lcurl-impersonate`` with
the explicit archive path to avoid selecting the adjacent dynamic library.
These release artifacts do not change the ordinary local install target, and
existing downstream binaries must be rebuilt to receive the new link options.

Release verification checks two native consumers after extracting the archive
into a path containing spaces: one relies on the embedded automatic link options,
and the other uses pkg-config flags with automatic linking disabled. Its include
and library search paths must resolve inside the extracted release, and the
selected static archive must be the one in that package. Both consumers must
transfer the expected file contents.

BSD family (FreeBSD / OpenBSD)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

BSD family operating systems are built natively, not with the
``zig`` cross toolchain. The release workflow runs a VM for each
BSD OS on an Ubuntu GitHub Actions runner and builds inside that
VM for the various architectures. The build currently disables
``libidn2`` because the standalone ``libidn2``
preparation step is not used on BSD.

Install the dependencies
^^^^^^^^^^^^^^^^^^^^^^^^

FreeBSD:

.. code-block:: bash

    pkg install -y git cmake ninja gmake

OpenBSD:

.. code-block:: bash

    pkg_add git cmake ninja gmake

Clone the repository
^^^^^^^^^^^^^^^^^^^^

.. code-block:: bash

    git clone https://github.com/lexiforest/curl-impersonate.git
    cd curl-impersonate

Configure and build
^^^^^^^^^^^^^^^^^^^

.. code-block:: bash

    cmake_args="-G Ninja -DCMAKE_INSTALL_PREFIX=$PWD/install -DUSE_LIBIDN2=OFF"

    gmake configure CMAKE_CONFIGURE_ARGS="$cmake_args"
    gmake build CMAKE_CONFIGURE_ARGS="$cmake_args"
    gmake install-strip CMAKE_CONFIGURE_ARGS="$cmake_args"

For FreeBSD, use the helper script in ``scripts/`` for local development from macOS.
It downloads an official FreeBSD cloud image, creates a QEMU/HVF VM, syncs this
repository into the VM, and runs the same native build:

.. code-block:: bash

    scripts/freebsd-vm-macos.sh setup
    scripts/freebsd-vm-macos.sh start
    scripts/freebsd-vm-macos.sh build
    scripts/freebsd-vm-macos.sh fetch-artifacts
    scripts/freebsd-vm-macos.sh stop

The VM state is stored in ``.freebsd-vm/``. Useful overrides include
``FREEBSD_RELEASE``, ``VM_ARCH``, ``VM_CPUS``, ``VM_MEM``, ``VM_DISK_SIZE``,
and ``SSH_PORT``. ``VM_ARCH`` defaults to ``host``. On Apple Silicon this means
an ARM64 FreeBSD VM, matching the ``aarch64-freebsd`` artifacts. Use
``VM_ARCH=amd64`` if you need to test ``x86_64-freebsd`` artifacts, but expect
it to be much slower because QEMU must emulate the CPU.

Static compilation
------------------

The CMake option for linking curl-impersonate statically with libcurl-impersonate
is ``-DBUILD_STATIC_CURL=ON``. The superbuild already passes this option to the
curl subproject, along with ``-DBUILD_STATIC_LIBS=ON`` and
``-DBUILD_SHARED_LIBS=ON``, so a normal ``make build`` produces the statically
linked executable and both static and shared libcurl-impersonate libraries.
No additional configuration flag is needed. System libraries may still be
dynamically linked.

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
