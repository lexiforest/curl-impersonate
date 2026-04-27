Installation
************

The easiest way to install curl-impersonate is to use the pre-built binaries from GitHub.

Pre-compiled binaries
=====================


Pre-compiled binaries for Windows, Linux and macOS are available at the
`GitHub releases <https://github.com/lexiforest/curl-impersonate/releases>`_ page. Before
you use them you may need to install ``zstd`` and CA certificates:

* Ubuntu - ``sudo apt install ca-certificates zstd libzstd-dev``
* Red Hat/Fedora/CentOS - ``yum install ca-certificates zstd libzstd-devel``
* Archlinux - ``pacman -S ca-certificates zstd``
* macOS - ``brew install ca-certificates zstd``

The pre-compiled binaries contain ``libcurl-impersonate`` and a statically compiled
``curl-impersonate`` for ease of use.

The pre-compiled Linux binaries are built for Ubuntu systems. On other distributions if
you have errors with certificate verification you may have to tell curl where to find the
CA certificates. For example:

.. code-block:: bash

    curl_chrome123 https://www.wikipedia.org --cacert /etc/ssl/certs/ca-bundle.crt

If you copy the binaries to another system, make sure the required runtime dependencies
are installed there as well.

Building from source
====================

See :doc:`building`.

Docker images
=============

Docker images based on Alpine Linux and Debian with `curl-impersonate` compiled and ready
to use are available on `Docker Hub <https://hub.docker.com/r/lexiforest/curl-impersonate>`_.
The images contain the binary and all the wrapper scripts. Use like the following:

.. code-block:: bash

    docker pull lexiforest/curl-impersonate:1.1.0
    docker run --rm lexiforest/curl-impersonate:1.1.0 curl_chrome110 https://www.wikipedia.org

Distro packages
===============

Arch Linux users can also look at the following AUR packages maintained for the upstream
project. Check the packaging details before relying on them with this fork:

* `curl-impersonate-bin <https://aur.archlinux.org/packages/curl-impersonate-bin>`_
* `libcurl-impersonate-bin <https://aur.archlinux.org/packages/libcurl-impersonate-bin>`_
* `curl-impersonate-chrome <https://aur.archlinux.org/packages/curl-impersonate-chrome>`_
