See docs/install.rst and docs/building.rst.

## Shared WebCrypto primitives

The shared library exports the narrow `bssl_webcrypto_*` interface declared in
`include/curl-impersonate/webcrypto.h`. It uses the same pinned BoringSSL instance
as curl's TLS implementation; BoringSSL's raw symbols remain private. Brimp uses
this interface for its WebCrypto backend without linking a second crypto library.

The bridge source lives in `src/webcrypto.cc`, with its public header in
`include/curl-impersonate/webcrypto.h`. It is not compiled into BoringSSL.
`cmake/WebCrypto.cmake` compiles it directly into curl's
shared and static targets. Keep the header, bridge and consumers synchronized
when changing the interface. The host owns WebCrypto validation, key usages,
extractability and realm lifetime; the bridge owns cryptographic primitives and
native key allocation. Release returned keys and buffers through this interface.

Windows static consumers must define `BSSL_WEBCRYPTO_STATIC` before including
the header so calls do not use DLL imports.

After building and installing, check the exported interface with:

```sh
python -m pytest tests/test_webcrypto.py --install-dir /path/to/sdk
```

The C++ consumer tests also cover authentication failures, key serialization,
signatures, RSA wrapping and ECDH. Run them against either the installed shared
library or the bundled static release archive:

```sh
cmake -S tests/webcrypto -B build/webcrypto-tests \
  -DBORINGSSL_SOURCE_DIR="$PWD/build/deps/src/boringssl" \
  -DSDK_INCLUDE_DIR=/path/to/sdk/include \
  -DCURL_LIBRARY=/path/to/sdk/lib/libcurl-impersonate.a
cmake --build build/webcrypto-tests
ctest --test-dir build/webcrypto-tests --output-on-failure
```
