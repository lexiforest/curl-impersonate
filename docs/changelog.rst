Changelog
*********

2.4.0
=====

curl-impersonate 2.4.0 is based on curl 8.23.0. Downloads for published releases
are available on the
`releases page <https://github.com/lexiforest/curl-impersonate/releases>`_.

Browser profiles and generation
-------------------------------

* Add ``chrome151``, ``chrome151_macos``, ``chrome152``, and ``chrome152_macos``
  for Chrome on Windows 10 and macOS 26.0, with HTTP/3 fingerprints.
* Add ``firefox153``, ``firefox154``, and ``firefox155`` for Firefox on Windows 10.
  These profiles provide TLS and HTTP/2 fingerprints.
* Add ``safari270`` and ``safari270_ios`` for Safari 27.0 on macOS 27.0 and iOS
  27.0, with HTTP/3 fingerprints.
* Add ``scripts/generate_fingerprints.py`` to generate presets, POSIX and Windows
  wrappers, signature YAML files, and test registry entries. It supports
  ``--csv`` batches, ``--remove``, and ``--dry-run``. Existing targets are
  replaced, and the preset array is sorted alphabetically.
* Generate partial TLS expectations and available HTTP/3 fields alongside
  HTTP/2 expectations. Explicit TLS and HTTP/3 captures take precedence.
* Use ``#!/bin/sh`` and ``exec`` in POSIX wrappers, and add the missing
  Windows wrapper for Chrome 150.

See :doc:`fingerprints` for target names and :doc:`dev` for the generator workflow.

Protocol changes and fixes
--------------------------

* Load HTTP/3 default headers from impersonation presets and select them based
  on the negotiated protocol. This fixes incorrect HTTP/3 headers for
  ``chrome152``, ``chrome152_macos``, and ``safari270_ios``, while retaining
  application overrides and the regular defaults on HTTP/2 fallback.
* Add opt-in WebSocket ``permessage-deflate`` through
  ``CURLWS_PERMESSAGE_DEFLATE`` in ``CURLOPT_WS_OPTIONS``. Compression is
  negotiated with the server and supports text and binary messages.
* Prevent origin HTTPS DNS-record queries from bypassing HTTP proxies or
  SOCKS4a/SOCKS5h remote DNS resolution.
* Correct ECH feature guards for builds with differing ECH support.
* Update HTTP/3 signature comparisons to handle the fingerprint endpoint's
  header-list format and additional normalized fingerprint fields.

Build and packaging
-------------------

* Add initial MinGW builds using Clang or GCC, with POSIX and Windows helpers.
* Add Android armv7 and x86 workflow targets alongside ARM64 and x86_64. Android
  uses the threaded resolver; other builds use c-ares.
* Add OpenBSD CI builds and use ``vswhere`` to locate Visual Studio on Windows.
* Install ``curl-impersonate-config`` and ``libcurl-impersonate.pc``, including
  static dependency metadata and archives for downstream builds.
* Fix macOS release pkg-config metadata to retain required system libraries
  and frameworks for static consumers.
* Improve libidn2 download reliability and verify its checksum.
* Fix Docker image identifiers in CI and include the missing C++ compiler in
  the Debian image build.

See :doc:`building` for build commands and linking guidance, and :doc:`api` for
the WebSocket option.

2.0.0
=====

curl-impersonate 2.0.0 is based on curl 8.21.0.

See the `2.0.0 release notes
<https://github.com/lexiforest/curl-impersonate/releases/tag/v2.0.0>`_ for the complete
list of changes and downloadable artifacts.

Older releases
==============

Release notes for older versions are available on the
`curl-impersonate releases <https://github.com/lexiforest/curl-impersonate/releases>`_
page.
