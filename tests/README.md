The tests verify that `curl-impersonate` has the same network signature as that of the supported browsers. They do not test curl's functionality itself.

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

## How the tests work
For each supported browser, the following tests are performed:
* A packet capture is started on the loopback interface while `curl-impersonate` is run with the relevant wrapper script against a local `nghttpd` server (a simple HTTP/2 server with TLS). The Client Hello message is extracted from the capture and compared against the known signature of the browser. Capturing against a local server keeps the test independent of external websites, and loopback traffic is never fragmented, so even large Client Hello messages (e.g. with post-quantum key shares) are parsed reliably.
* `curl-impersonate` is run, connecting to the same local `nghttpd` server. The HTTP/2 pseudo-headers and headers are extracted from the output log of `nghttpd` and compared to the known headers of the browser.
* HTTP/3-enabled profiles connect to `https://fp.impersonate.pro/api/http3` with both the wrapper and the `CURL_IMPERSONATE`/`LD_PRELOAD` libcurl path. Stable HTTP/3, QUIC, header, and QUIC TLS fields are compared with the profile's `http3` section in `signatures/`. These are the only tests that require internet access; they are marked with the `remote` pytest marker and can be skipped with `pytest -m "not remote"`.
* The same HTTP/3 clients connect in fallback mode to the local HTTP/2-only server, and the resulting HTTP/2 signature is checked.

## What's missing
The following tests are still missing:

- [x] Test that `curl-impersonate` sends the same HTTP/2 SETTINGS as the browser.
- [x] Update safari versions, double `rsa_pss_rsae_sha384`
