# Getting started with curl-impersonate

curl-impersonate can be run on Linux and macOS. Windows is supported via mingw.

## Installation
Installation instructions are available on the [main page](https://github.com/lexiforest/curl-impersonate#installation)

The project supplies a modified curl binary and libcurl library that can impersonate Chrome, Edge, Safari and Firefox. It uses BoringSSL, Chrome's TLS library. It is based on a patched curl version with added support for some additional TLS extensions and modified HTTP/2 settings that make it look like a browser.
