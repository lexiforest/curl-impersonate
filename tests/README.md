The tests verify that `curl-impersonate` has the same network signature as that of the supported browsers. They do not test curl's functionality itself.

## Running the tests

The tests assume that you've built the `curl-impersonate` docker image before.
See [Building from source](../docs/02_install.md#building-from-source).

To run the tests, build with:
```
docker build -t curl-impersonate-tests tests/
```
then run with:
```
docker run --rm curl-impersonate-tests
```
This simply runs `pytest` in the container. You can pass additional flags to `pytest` such as `--log-cli-level DEBUG`.

For example, to run only the HTTP/3 tests:

```
docker run --rm curl-impersonate-tests -k http3 --log-cli-level DEBUG
```

## How the tests work
For each supported browser, the following tests are performed:
* A packet capture is started while `curl-impersonate` is run with the relevant wrapper script. The Client Hello message is extracted from the capture and compared against the known signature of the browser.
* `curl-impersonate` is run, connecting to a local `nghttpd` server (a simple HTTP/2 server). The HTTP/2 pseudo-headers and headers are extracted from the output log of `nghttpd` and compared to the known headers of the browser.
* HTTP/3-enabled targets are run against a local `aioquic` server. The server records the HTTP/3 pseudo-headers, request headers, HTTP/3 SETTINGS, and raw QUIC transport parameters and compares them to the expected target fingerprint.

## What's missing
The following tests are still missing:

- [x] Test that `curl-impersonate` sends the same HTTP/2 SETTINGS as the browser.
- [x] Update safari versions, double `rsa_pss_rsae_sha384`
