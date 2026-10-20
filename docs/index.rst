.. curl-impersonate documentation master file, created by
   sphinx-quickstart on Sat Feb 17 22:22:59 2024.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

curl-impersonate (lexiforest's fork)
====================================

.. toctree::
   :maxdepth: 2
   :caption: Contents:

   install
   building
   quick_start
   fingerprints
   bindings
   api
   faq
   changelog
   dev
   pro

.. note::

   This documentation covers `lexiforest's fork <https://github.com/lexiforest/curl-impersonate>`_
   of curl-impersonate.

This documentation covers curl-impersonate 2.3.0, based on curl 8.23.0.
See :doc:`changelog` for recent changes and the
`releases page <https://github.com/lexiforest/curl-impersonate/releases>`_ for
published releases and downloads.

``curl-impersonate`` is a curl build that makes HTTP requests look like they came from a
real browser. It can impersonate recent versions of Chrome, Edge, Safari, Firefox, and
Tor.

You can use curl-impersonate either as a command-line tool, much like regular curl, or
as a library in place of regular libcurl.

The project supports all major platforms, including macOS, Linux, Windows, Android, and
iOS. It can also be built on systems such as BSD with minor changes, although those
platforms are not officially supported.

Compared with upstream curl, this distribution includes patched BoringSSL, Chrome's TLS
library, and a few other patched components to reproduce browser TLS and HTTP
fingerprints as closely as possible.

HTTP/3 is enabled by default in this distribution.

Join our `community on discord <https://discord.gg/kJqMHHgdn2>`_.


Indices and tables
==================

* :ref:`genindex`
* :ref:`modindex`
* :ref:`search`
