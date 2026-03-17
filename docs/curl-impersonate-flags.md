# curl-impersonate Custom Flags Reference

These are the flags added by curl-impersonate on top of standard curl. All standard curl flags continue to work as normal.

---

## Master Impersonation

### `--impersonate <target>`
**libcurl:** `CURLOPT_IMPERSONATE` (string)

Sets all TLS, HTTP/2, HTTP/3, and header options at once to match a browser's fingerprint. This is the recommended way to use curl-impersonate.

Format: `target[:yes|no]` — the optional suffix controls whether default browser HTTP headers are included (default: yes).

**Available targets:**

| Target | Description |
|--------|-------------|
| `chrome99` | Chrome 99 (Windows) |
| `chrome99_android` | Chrome 99 (Android) |
| `chrome100` | Chrome 100 |
| `chrome101` | Chrome 101 |
| `chrome104` | Chrome 104 |
| `chrome107` | Chrome 107 |
| `chrome110` | Chrome 110 |
| `chrome116` | Chrome 116 |
| `chrome119` | Chrome 119 |
| `chrome120` | Chrome 120 |
| `chrome123` | Chrome 123 |
| `chrome124` | Chrome 124 |
| `chrome131` | Chrome 131 |
| `chrome131_android` | Chrome 131 (Android) |
| `chrome133a` | Chrome 133 |
| `chrome136` | Chrome 136 |
| `chrome142` | Chrome 142 |
| `chrome145` | Chrome 145 |
| `edge99` | Edge 99 |
| `edge101` | Edge 101 |
| `firefox133` | Firefox 133 |
| `firefox135` | Firefox 135 |
| `firefox144` | Firefox 144 |
| `firefox147` | Firefox 147 |
| `safari153` | Safari 15.3 |
| `safari155` | Safari 15.5 |
| `safari170` | Safari 17.0 |
| `safari172_ios` | Safari 17.2 (iOS) |
| `safari180` | Safari 18.0 (macOS) |
| `safari180_ios` | Safari 18.0 (iOS) |
| `safari184` | Safari 18.4 (macOS) |
| `safari184_ios` | Safari 18.4 (iOS) |
| `safari260` | Safari 26.0 (macOS) |
| `safari2601` | Safari 26.0.1 (macOS) |
| `safari260_ios` | Safari 26.0 (iOS) |
| `okhttp4_android` | OkHttp 4 (Android) |
| `tor145` | Tor Browser 14.5 (based on Firefox 128) |
| `mitmproxy` | mitmproxy |

```bash
curl-impersonate --impersonate chrome131 https://example.com
curl-impersonate --impersonate chrome131:no -H "User-Agent: custom" https://example.com
```

---

## TLS Flags

### `--signature-hashes <list>`
**libcurl:** `CURLOPT_SSL_SIG_HASH_ALGS` (string)

Colon-separated list of TLS signature algorithms to advertise in the ClientHello (extension 13).

**Supported algorithm names:**

| ID | Name |
|----|------|
| 0x0201 | `rsa_pkcs1_md5_sha1` |
| 0x0201 | `rsa_pkcs1_sha1` |
| 0x0401 | `rsa_pkcs1_sha256` |
| 0x0501 | `rsa_pkcs1_sha384` |
| 0x0601 | `rsa_pkcs1_sha512` |
| 0x0203 | `ecdsa_sha1` |
| 0x0403 | `ecdsa_secp256r1_sha256` |
| 0x0503 | `ecdsa_secp384r1_sha384` |
| 0x0603 | `ecdsa_secp521r1_sha512` |
| 0x0804 | `rsa_pss_rsae_sha256` |
| 0x0805 | `rsa_pss_rsae_sha384` |
| 0x0806 | `rsa_pss_rsae_sha512` |
| 0x0807 | `ed25519` |
| 0x0809 | `rsa_pss_pss_sha256` |
| 0x080a | `rsa_pss_pss_sha384` |
| 0x080b | `rsa_pss_pss_sha512` |
| 0x0808 | `ed448` |
| 0x081a | `ecdsa_brainpoolP256r1tls13_sha256` |
| 0x081b | `ecdsa_brainpoolP384r1tls13_sha384` |
| 0x081c | `ecdsa_brainpoolP512r1tls13_sha512` |
| 0x0301 | `rsa_pkcs1_sha224` |
| 0x0303 | `ecdsa_sha224` |
| 0x0302 | `dsa_sha224` |
| 0x0402 | `dsa_sha256` |
| 0x0502 | `dsa_sha384` |
| 0x0602 | `dsa_sha512` |
| 0x0904 | `mldsa44` |
| 0x0905 | `mldsa65` |
| 0x0906 | `mldsa87` |

```bash
curl-impersonate --signature-hashes "ecdsa_secp256r1_sha256:rsa_pss_rsae_sha256:rsa_pkcs1_sha256:ecdsa_sha1:rsa_pkcs1_sha1" https://example.com
```

### `--cert-compression <algorithms>`
**libcurl:** `CURLOPT_SSL_CERT_COMPRESSION` (string)

Comma-separated list of TLS certificate compression algorithms (RFC 8879, extension 27). Supported values: `zlib`, `brotli`.

```bash
curl-impersonate --cert-compression brotli https://example.com
```

### `--alps` / `--no-alps`
**libcurl:** `CURLOPT_SSL_ENABLE_ALPS` (long, 0/1)

Enable or disable the ALPS TLS extension (Application-Layer Protocol Settings). Used by Chrome.

### `--tls-session-ticket` / `--no-tls-session-ticket`
**libcurl:** `CURLOPT_SSL_ENABLE_TICKET` (long, 0/1)

Enable or disable the TLS session ticket extension (RFC 5077).

### `--tls-permute-extensions` / `--no-tls-permute-extensions`
**libcurl:** `CURLOPT_SSL_PERMUTE_EXTENSIONS` (long, 0/1)

Enable BoringSSL's TLS extension permutation. Used by Chrome 110+ to randomize extension order.

### `--tls-grease` / `--no-tls-grease`
**libcurl:** `CURLOPT_TLS_GREASE` (long, 0/1)

Enable TLS GREASE (Generate Random Extensions And Sustain Extensibility). Inserts random unknown values into the ClientHello to test server tolerance.

### `--tls-extension-order <order>`
**libcurl:** `CURLOPT_TLS_EXTENSION_ORDER` (string)

Dash-separated list of TLS extension type IDs controlling the order of extensions in the ClientHello.

**Important: this is both an ordering AND a filtering mechanism.** Only extensions whose type IDs appear in the list will be included in the ClientHello. Extensions that are "enabled" (e.g. via `--tls-signed-cert-timestamps` or the hardcoded `status_request`) but not listed in the order string will be silently omitted. This is how the mitmproxy profile excludes `status_request` (5) even though the CLI tool unconditionally enables it.

When this option is `NULL` (as for Chrome profiles), BoringSSL uses its default order and includes all enabled extensions. When set explicitly (Firefox, Tor, mitmproxy profiles), it gives precise control over both presence and order.

If `--tls-permute-extensions` is also enabled, the listed extensions are randomly shuffled (but still limited to only those listed).

**Available extension type IDs:**

| ID | Name | Notes |
|----|------|-------|
| 0 | `server_name` (SNI) | Almost always present |
| 5 | `status_request` (OCSP stapling) | Hardcoded on by CLI, but filtered by extension order |
| 10 | `supported_groups` (curves) | Always present when curves are configured |
| 11 | `ec_point_formats` | Present for EC-based cipher suites |
| 13 | `signature_algorithms` | Always present in TLS 1.2+ |
| 14 | `srtp` | For DTLS-SRTP |
| 16 | `alpn` | Application-Layer Protocol Negotiation |
| 18 | `certificate_timestamp` (SCT) | Controlled by `--tls-signed-cert-timestamps` |
| 21 | `padding` | Added automatically by BoringSSL to reach target size |
| 22 | `encrypt_then_mac` | Controlled by `CURLOPT_TLS_ENCRYPT_THEN_MAC` (libcurl only) |
| 23 | `extended_master_secret` | Always sent by BoringSSL |
| 27 | `cert_compression` | Controlled by `--cert-compression` |
| 28 | `record_size_limit` | Controlled by `--tls-record-size-limit` |
| 34 | `delegated_credential` | Controlled by `--tls-delegated-credentials` |
| 35 | `session_ticket` | Controlled by `--tls-session-ticket` |
| 41 | `pre_shared_key` (PSK) | TLS 1.3 resumption |
| 42 | `early_data` | TLS 1.3 0-RTT |
| 43 | `supported_versions` | Always present in TLS 1.3 |
| 45 | `psk_key_exchange_modes` | Always present in TLS 1.3 |
| 51 | `key_share` | Always present in TLS 1.3 |
| 57 | `quic_transport_parameters` | HTTP/3 only |
| 17513 | `application_settings` (ALPS, old) | Old ALPS code point |
| 17613 | `application_settings` (ALPS, new) | New ALPS code point, `--tls-use-new-alps-codepoint` |
| 65037 (0xfe0d) | `encrypted_client_hello` (ECH) | Controlled by `--ech` |
| 65281 (0xff01) | `renegotiation_info` | Always present in TLS 1.2 |

```bash
# Firefox 135 extension order
curl-impersonate --tls-extension-order "0-23-65281-10-11-35-16-5-34-18-51-43-13-45-28-27-65037" https://example.com

# mitmproxy extension order (note: no 5/status_request, no 18/SCT)
curl-impersonate --tls-extension-order "65281-0-11-10-35-16-22-23-13-43-45-51" https://example.com
```

### `--tls-use-new-alps-codepoint` / `--no-tls-use-new-alps-codepoint`
**libcurl:** `CURLOPT_TLS_USE_NEW_ALPS_CODEPOINT` (long, 0/1)

Use the new ALPS TLS extension code point (used by newer Chrome versions).

### `--tls-signed-cert-timestamps` / `--no-tls-signed-cert-timestamps`
**libcurl:** `CURLOPT_TLS_SIGNED_CERT_TIMESTAMPS` (long, 0/1)

Enable the signed certificate timestamps TLS extension (SCT, extension 18).

### `--tls-delegated-credentials <list>`
**libcurl:** `CURLOPT_TLS_DELEGATED_CREDENTIALS` (string)

Colon-separated list of signature algorithms for TLS delegated credentials (used by Firefox). Uses the same algorithm names as `--signature-hashes`.

```bash
curl-impersonate --tls-delegated-credentials "ecdsa_secp256r1_sha256:ecdsa_secp384r1_sha384:ecdsa_secp521r1_sha512:ecdsa_sha1" https://example.com
```

### `--tls-record-size-limit <value>`
**libcurl:** `CURLOPT_TLS_RECORD_SIZE_LIMIT` (long)

Set the TLS record size limit extension value (used by Firefox).

### `--tls-key-shares-limit <value>`
**libcurl:** `CURLOPT_TLS_KEY_SHARES_LIMIT` (long)

Limit the number of key shares sent in the ClientHello (used by Firefox to send fewer key shares than Chrome).

---

## HTTP/2 Flags

### `--http2-pseudo-headers-order <order>`
**libcurl:** `CURLOPT_HTTP2_PSEUDO_HEADERS_ORDER` (string)

Set the order of HTTP/2 pseudo-headers in the HEADERS frame. The value must contain the letters `m`, `a`, `s`, `p` representing `:method`, `:authority`, `:scheme`, `:path`.

```bash
# Chrome uses "masp", Firefox uses "mpas"
curl-impersonate --http2-pseudo-headers-order "masp" https://example.com
```

### `--http2-settings <settings>`
**libcurl:** `CURLOPT_HTTP2_SETTINGS` (string)

Set HTTP/2 SETTINGS frame parameters. Format: `key:value` pairs separated by semicolons.

Standard HTTP/2 settings IDs:
- `1` = HEADER_TABLE_SIZE
- `2` = ENABLE_PUSH
- `3` = MAX_CONCURRENT_STREAMS
- `4` = INITIAL_WINDOW_SIZE
- `5` = MAX_FRAME_SIZE
- `6` = MAX_HEADER_LIST_SIZE

```bash
# Chrome-style settings
curl-impersonate --http2-settings "1:65536;2:0;3:1000;4:6291456;6:262144" https://example.com
```

### `--http2-window-update <value>`
**libcurl:** `CURLOPT_HTTP2_WINDOW_UPDATE` (long)

Set the initial HTTP/2 WINDOW_UPDATE value sent after connection. Use `-1` to disable.

```bash
curl-impersonate --http2-window-update 15663105 https://example.com
```

### `--http2-streams <spec>`
**libcurl:** `CURLOPT_HTTP2_STREAMS` (string)

Set initial HTTP/2 PRIORITY stream dependencies.

### `--http2-stream-weight <value>`
**libcurl:** `CURLOPT_STREAM_WEIGHT` (long)

Set the HTTP/2 stream weight (0-255).

### `--http2-stream-exclusive <value>`
**libcurl:** `CURLOPT_STREAM_EXCLUSIVE` (long, 0/1)

Set the HTTP/2 stream exclusive flag.

### `--http2-no-priority` / `--no-http2-no-priority`
**libcurl:** `CURLOPT_HTTP2_NO_PRIORITY` (long, 0/1)

Disable the priority bit in HTTP/2 HEADERS frames. Used by newer browsers that no longer use HTTP/2 priority.

---

## HTTP/3 / QUIC Flags

### `--http3-pseudo-headers-order <order>`
**libcurl:** (string)

Same as `--http2-pseudo-headers-order` but for HTTP/3 HEADERS frames.

### `--http3-settings <settings>`
**libcurl:** (string)

HTTP/3 SETTINGS in the same `key:value;...` format as `--http2-settings`. Supports `GREASE` as a special value.

```bash
curl-impersonate --http3-settings "1:65536;6:262144;7:100;51:1;GREASE" https://example.com
```

### `--quic-transport-params <params>`
**libcurl:** (string)

QUIC transport parameters. Semicolon-separated `key:value` pairs. Supports special values like `AUTO`, `GREASE`, and `@` for sub-parameters.

```bash
curl-impersonate --quic-transport-params "1:30000;3:1472;4:15728640;5:6291456;6:6291456;7:6291456;8:100;9:103;15:;17:1@1,GREASE;32:65536;12583:AUTO;18258:1;GREASE" https://example.com
```

---

## HTTP Behavior Flags

### `--split-cookies` / `--no-split-cookies`
**libcurl:** `CURLOPT_SPLIT_COOKIES` (long, 0/1)

Split cookies into separate `Cookie:` headers (one per name=value pair) instead of combining them into a single header. Some browsers do this in certain contexts.

### `--proxy-credential-no-reuse` / `--no-proxy-credential-no-reuse`
**libcurl:** `CURLOPT_PROXY_CREDENTIAL_NO_REUSE` (long, 0/1)

Do not reuse TLS sessions or connections from different proxy credentials.

---

## Standard curl Flags Relevant to Impersonation

These are not curl-impersonate additions, but are important for fingerprint matching.

### `--ech <config>`
**libcurl:** `CURLOPT_ECH` (string)

Standard curl flag for Encrypted Client Hello (extension 65037). Common values: `true`, `grease`, `hard`, or a base64 ECH config.

```bash
curl-impersonate --ech true https://example.com
curl-impersonate --ech grease https://example.com
```

---

## libcurl-Only Options

These options are available via the C API but do not have corresponding CLI flags:

### `CURLOPT_HTTPBASEHEADER` (slist)
A list of HTTP headers used by the impersonated browser. When set, these are merged with `CURLOPT_HTTPHEADER`. Used internally by `curl_easy_impersonate()`.

### `CURLOPT_TLS_KEY_USAGE_NO_CHECK` (long, 0/1)
Disable TLS key usage checking.

### `CURLOPT_TLS_STATUS_REQUEST` (long, 0/1)
Enable the TLS status request / OCSP stapling extension (type 5). Off by default in BoringSSL, but **hardcoded on** in the `curl-impersonate` CLI binary (unconditionally set in the tool's `operate()` function). There is no CLI flag to disable it. The libcurl API is the only way to control this.

### `CURLOPT_TLS_ENCRYPT_THEN_MAC` (long, 0/1)
Send the encrypt_then_mac TLS extension (type 22). Used by the mitmproxy profile.

### `CURLOPT_TLS_EC_POINT_FORMATS_ALL` (long, 0/1)
Advertise all EC point formats (uncompressed + compressed), not just uncompressed. Used by the mitmproxy profile.

### `CURLOPT_FORM_BOUNDARY` (string)
Set multipart/form-data boundary style. Known value: `"webkit"` for WebKit-style boundaries.

---

## Notes

- Boolean flags support `--no-` prefix to disable (e.g., `--no-alps`, `--no-tls-grease`).
- When using `--impersonate`, all the above flags are set automatically from the browser profile. You can override individual settings by specifying flags after `--impersonate`.
- Standard curl TLS flags (`--ciphers`, `--curves`, `--tls13-ciphers`, `--tlsv1.2`, etc.) continue to work and also affect the fingerprint.
