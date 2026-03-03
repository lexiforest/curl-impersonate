# curl-impersonate Testing & Inspection Infrastructure

## Overview
The repo has a multi-layered test system for verifying that curl-impersonate's wire-level behavior matches real browsers.

## 1. TLS Client Hello Signature Verification (packet capture)
- **Test**: `test_tls_client_hello` in `tests/test_impersonate.py:212-296`
- Starts `tcpdump` capturing port-443 traffic on local ports 50000-50100
- Runs curl-impersonate against real public websites
- Feeds raw pcap bytes to `th1.tls.parser.parse_pcap()` (uses `dpkt`)
- Compares captured TLS Client Hello field-by-field against YAML signature database
- **What's compared**: cipher suite list (exact order, GREASE tokens), TLS extensions (type, order, contents), compression methods, record/handshake version, session ID length, extension permutation (Chrome 110+)

## 2. HTTP/2 Signature Verification (server log)
- **Test**: `test_http2_headers` in `tests/test_impersonate.py:299-348`
- Starts local `nghttpd` (HTTP/2 debug server from nghttp2) with verbose logging
- Parses nghttpd log via `th1.http2.parser.parse_nghttpd_log()`
- **What's compared**: SETTINGS frame values, WINDOW_UPDATE values, HEADERS frame (exact headers + order), pseudo-header order (e.g. Chrome=m,a,s,p vs Safari=m,s,a,p)

## 3. Signature YAML Database (`tests/signatures/`)
- ~40 YAML files, one per browser version
- **`tls_client_hello`**: cipher suites (numeric IDs), every TLS extension with params (key shares, supported versions, sig hash algs, ALPN, GREASE positions)
- **`http2`**: SETTINGS key-values, WINDOW_UPDATE, HEADERS with exact header list and pseudo-header order
- **`third_party`**: JA3/JA3N hash+text, Akamai HTTP/2 fingerprint hash+text
- **`options`**: e.g. `tls_permute_extensions: true` for Chrome 110+

## 4. `minicurl` — LD_PRELOAD Testing (`tests/minicurl.c`)
- Minimal C program linked against stock libcurl
- `libcurl-impersonate.so` injected via `LD_PRELOAD` + `CURL_IMPERSONATE=<target>` env var
- Same TLS and HTTP/2 signature tests run against it
- Verifies `curl_easy_impersonate()` API produces identical wire-level behavior to wrapper scripts

## 5. Additional Behavioral Tests
- `test_no_builtin_headers` (line 352): `CURL_IMPERSONATE_HEADERS=no` suppresses built-in headers, respects user header order
- `test_user_agent` (line 428): User-Agent via `-H` overrides built-in
- `test_user_agent_curlopt_useragent` (line 487): User-Agent via `-A` (CURLOPT_USERAGENT) overrides built-in

## 6. The `th1` Library (external: `lexiforest/th1`)
- `parse_pcap()` — extracts TLS Client Hello signatures from raw pcap bytes
- `TLSClientHelloSignature.from_bytes()` / `.from_dict()` / `.equals()` — structured TLS comparison
- `parse_nghttpd_log()` — parses HTTP/2 frames from nghttpd verbose output
- `HTTP2Signature.from_dict()` / `.equals()` — structured HTTP/2 comparison
- JSON canonicalization + SHA1 hashing for fingerprint generation

## 7. Test Targets (`tests/targets.yaml`)
- Maps each wrapper script (e.g. `curl_chrome131`) to its expected signature YAML key
- Also maps `minicurl` + `CURL_IMPERSONATE=<target>` + `libcurl-impersonate` LD_PRELOAD combos
- Parametrizes pytest so every browser version is tested for both CLI and library paths

## 8. Test Infrastructure
- `tests/conftest.py`: pytest options `--install-dir` and `--capture-interface`
- `tests/ssl/`: self-signed certs (server.key, server.crt, dhparam.pem) for local nghttpd
- `tests/Dockerfile`: builds test image from curl-impersonate image, installs tcpdump + nghttpd + minicurl
- `tests/pytest.ini`: `asyncio_mode = auto`
- Requirements: pyyaml, pytest, pytest-asyncio, th1, dpkt

## Gaps / What's NOT present
- No HTTP/3 (QUIC) signature tests yet (H3 fingerprints marked for chrome145/firefox147 only)
- No automated tool to capture real browser signatures and generate YAML (done manually/externally)
- Comparison is at parsed/structured level, not raw hex byte diff
- `th1` is not well-documented; its internals need source inspection for deeper understanding
