Installation
************

The easiest way to install curl-impersonate is to use the package manager or prebuilt
binaries from GitHub.

Using package manager
=====================

For macOS:

.. code-block:: bash

    brew install lexiforest/tap/curl-impersonate

For Arch Linux:

.. code-block:: bash

    sudo pacman -S curl-impersonate

Pre-compiled binaries
=====================

Precompiled binaries for macOS, Linux, and Windows are available on the
`GitHub releases <https://github.com/lexiforest/curl-impersonate/releases>`_ page.
Before using them, you may need to install a CA certificate package:

* Ubuntu - ``apt install ca-certificates``
* Red Hat/Fedora/CentOS - ``yum install ca-certificates``
* Archlinux - ``pacman -S ca-certificates``
* macOS - ``brew install ca-certificates``

The prebuilt binaries include ``libcurl-impersonate`` as both a shared library and a
static archive, as well as a statically linked ``curl-impersonate`` binary for ease of
use. These artifacts only rely on the target system's standard runtime libraries.

The Linux binaries are built on Ubuntu. On other distributions, if you see certificate
verification errors, you may need to tell curl where to find the
CA certificates. For example:

.. code-block:: bash

    curl_chrome123 https://www.example.com --cacert /etc/ssl/certs/ca-bundle.crt

Building from source
====================

See :doc:`building`.

Docker images
=============

Docker images based on Alpine Linux and Debian, with ``curl-impersonate`` already built,
are available on `Docker Hub <https://hub.docker.com/r/lexiforest/curl-impersonate>`_.
These images include the binary and all wrapper scripts. For example:

.. code-block:: bash

    docker pull lexiforest/curl-impersonate:1.1.0
    docker run --rm lexiforest/curl-impersonate:1.1.0 curl_chrome110 https://www.example.com
