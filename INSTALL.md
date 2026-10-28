See docs/install.rst and docs/building.rst.

## Shared WebCrypto primitives

The shared library exports the narrow `bssl_webcrypto_*` interface declared in
`include/curl-impersonate/webcrypto.h`. It uses the same pinned BoringSSL instance
as curl's TLS implementation; BoringSSL's raw symbols remain private. Brimp uses
this interface for its WebCrypto backend without linking a second crypto library.

The bridge source lives in the BoringSSL fork and is included in
`patches/boringssl.patch`. `cmake/WebCrypto.cmake` compiles it directly into curl's
shared and static targets. Keep the header, bridge and consumers synchronized
when changing the interface. The host owns WebCrypto validation, key usages,
extractability and realm lifetime; the bridge owns cryptographic primitives and
native key allocation. Release returned keys and buffers through this interface.

After building and installing, check the exported interface with:

```sh
python -m pytest tests/test_webcrypto.py --install-dir /path/to/sdk
```
