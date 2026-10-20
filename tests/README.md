The tests verify that `curl-impersonate` has the same network signature as that of the supported browsers, and smoke-test WebSocket functionality.

See the [generator guide](../docs/dev.rst) for JSON inputs, CSV batches,
replacement and removal behavior, and patch export.

`scripts/generate_fingerprints.py` generates HTTP/2 expectations, HTTP/3 settings,
pseudo-header order, QUIC transport parameters and headers when available, and
TLS expectations marked `partial: true`. Partial TLS checks cover the supplied
ciphers, extension order, groups and extension parameters without assuming
packet lengths, record versions or session ID lengths. Supplied
`signature.tls_client_hello` and `signature.http3` captures take precedence and
retain their full checks. Regenerate existing profiles to add the new sections.

Partial TLS expectations use th1's `ciphersuites` and ordered `extensions`
structure, including named extension types and fields such as `sig_hash_algs`.
Unknown fields are omitted. The `grease` flag checks presence without assuming
GREASE positions or payloads. The test suite uses its local comparison adapter
for these partial expectations and uses th1's `TLSClientHelloSignature` for
full captures. HTTP/3 comparisons also run through the local helper in
`test_impersonate.py`.

Run the generator's offline regression tests with:

```sh
cd tests && pytest test_generate_fingerprints.py -q
```

## Running the tests

The tests assume that you've built `curl-impersonate` docker image before (see [Building from source](https://github.com/lwthiker/curl-impersonate#building-from-source)).

To run the tests, build with:
```
docker build -t curl-impersonate-tests tests/
```
then run with:
```
docker run --rm curl-impersonate-tests
```
This simply runs `pytest` in the container. You can pass additional flags to `pytest` such as `--log-cli-level DEBUG`.

### WebSocket smoke tests

Run just the WebSocket tests against an installed build on Linux or macOS:

```sh
python3 -m pip install pytest pytest-asyncio 'websockets>=15,<16'
python3 -m pytest tests/test_websocket.py --install-dir <install-prefix> -v
```

These tests compile a small C client against the headers and shared library in
the install prefix (using `CC`, or `cc` by default). They run a loopback echo
server and require neither Internet access nor packet-capture privileges.
Both `ws://` and `wss://` are tested without impersonation and with Chrome 150,
Firefox 144, and Safari 26.0 profiles. Each case checks the HTTP 101 upgrade,
text and binary echoes (including chunked reads), ping/pong, and normal closure.
The basic cases disable compression. A separate Chrome test enables
`CURLWS_PERMESSAGE_DEFLATE` over both schemes and checks extension negotiation,
compressed text and binary frames in both directions, repeated messages with
context takeover, and uncompressed control frames. This requires a build with
the `CURLWS_PERMESSAGE_DEFLATE` API. TLS uses the existing self-signed test certificate
with certificate verification disabled in the smoke client.

The existing CI and Docker `pytest` runs discover these tests automatically.

## How the tests work
For each supported browser, the following tests are performed:
* A packet capture is started while `curl-impersonate` is run with the relevant wrapper script. The Client Hello message is extracted from the capture and compared against the known signature of the browser.
* `curl-impersonate` is run, connecting to a local `nghttpd` server (a simple HTTP/2 server). The HTTP/2 pseudo-headers and headers are extracted from the output log of `nghttpd` and compared to the known headers of the browser.
* HTTP/3-enabled profiles connect to `https://fp.impersonate.pro/api/http3` with both the wrapper and the `CURL_IMPERSONATE`/`LD_PRELOAD` libcurl path. Stable HTTP/3, QUIC, header, and QUIC TLS fields are compared with the profile's `http3` section in `signatures/`.
* `curl-impersonate` connects to the same HTTP/3 endpoint through a local SOCKS5 UDP proxy. Both `--http3` and `--http3-only` are tested with local (`socks5`) and proxy-side (`socks5h`) DNS resolution.
* The same HTTP/3 clients connect in fallback mode to the local HTTP/2-only server, and the resulting HTTP/2 signature is checked.

## What's missing
The following tests are still missing:

- [x] Test that `curl-impersonate` sends the same HTTP/2 SETTINGS as the browser.
- [x] Update safari versions, double `rsa_pss_rsae_sha384`
