API Reference
=============

The following ``CURLOPT_*`` options and CLI arguments are added by curl-impersonate and 
are not part of upstream curl.

Many of them are applied automatically by ``curl_easy_impersonate()`` given a preset
fingerprint. 

If you want to customize the fingerprint, or create your own impersonation target, below
is all the options we have added on top of vanilla curl:

Impersonation and Headers
-------------------------

``CURLOPT_IMPERSONATE`` (string)
  The master option for setting an impersonation target. The format is
  ``name[:yes|no]``. The optional suffix controls whether default browser headers are
  enabled.
  Command line: ``--impersonate <target>``.

``CURLOPT_HTTPBASEHEADER`` (slist)
  A list of headers used by the impersonated browser. If given, it is merged with
  ``CURLOPT_HTTPHEADER``. When ``curl_easy_impersonate()`` is called with
  ``default_headers`` enabled, this is where the built-in browser header set is applied.
  Command line: no direct equivalent.

``CURLOPT_HTTPHEADER_ORDER`` (string)
  Comma-separated order for normal HTTP headers. e.g. ``Host,User-Agent,Cookie``. This
  is particularly useful for impersonating the http/1.1 behavior.
  Command line: ``--http-header-order <headers>``.

``CURLOPT_FORM_BOUNDARY`` (string)
  Sets the multipart ``form-data`` boundary style. Possible values: ``webkit``, for
  webkit and blink based browsers, e.g. Safari and Chrome. ``firefox``, for Gecko based
  browsers, e.g. Firefox.
  Command line: no direct equivalent.

TLS
---

``CURLOPT_SSL_SIG_HASH_ALGS`` (string)
  Sets the TLS signature hash algorithms. Note that upstream curl later
  implemented a similar option as option 328, but curl-impersonate keeps this name for
  compatibility. See RFC 5246 section 7.4.1.4.1.
  Command line: ``--signature-hashes <algorithm list>``.

``CURLOPT_SSL_ENABLE_ALPS`` (long)
  Enables or disables ALPS in TLS. Note that recent versions of Chrome started using a
  new ID for ALPS.
  Command line: ``--alps``.

``CURLOPT_SSL_CERT_COMPRESSION`` (string)
  Comma-separated list of certificate compression algorithms to advertise in the TLS
  ClientHello. Supported values are ``zlib`` and ``brotli`` and ``zstd``. See RFC 8879.
  Command line: ``--cert-compression <algorithm list>``.

``CURLOPT_SSL_ENABLE_TICKET`` (long)
  Enables or disables the TLS session ticket extension defined by RFC 5077.
  Command line: ``--tls-session-ticket`` / ``--no-tls-session-ticket``.

``CURLOPT_SSL_PERMUTE_EXTENSIONS`` (long)
  Enables or disables BoringSSL's permuted-extension behavior. This is the default
  behavior of Chrome 110 and later.
  Command line: ``--tls-permute-extensions``.

``CURLOPT_TLS_GREASE`` (long)
  Enables TLS GREASE behavior.
  Command line: ``--tls-grease``.

``CURLOPT_TLS_EXTENSION_ORDER`` (string)
  Sets an explicit TLS extension order, in a format such as ``0-5-10``.
  Command line: ``--tls-extension-order <order>``.

``CURLOPT_TLS_KEY_USAGE_NO_CHECK`` (long)
  Disable the TLS key usage check.
  Command line: no direct equivalent.

``CURLOPT_TLS_SIGNED_CERT_TIMESTAMPS`` (long)
  Enables TLS signed certificate timestamps.
  Command line: ``--tls-signed-cert-timestamps``.

``CURLOPT_TLS_STATUS_REQUEST`` (long)
  Enables the TLS status request extension.
  Command line: no direct equivalent.

``CURLOPT_TLS_DELEGATED_CREDENTIALS`` (string)
  Controls Firefox-style delegated credentials. e.g. ``ecdsa_secp256r1_sha256:ecdsa_secp384r1_sha384:ecdsa_secp521r1_sha512:ecdsa_sha1``
  Command line: ``--tls-delegated-credentials <value>``.

``CURLOPT_TLS_RECORD_SIZE_LIMIT`` (long)
  Controls Firefox-style TLS record size limit behavior. The typical value is ``4001``
  Command line: ``--tls-record-size-limit <integer>``.

``CURLOPT_TLS_KEY_SHARES_LIMIT`` (long)
  Controls Firefox-style ``key_shares_limit`` behavior. The typical value is ``3``
  Command line: ``--tls-key-shares-limit <integer>``.

``CURLOPT_TLS_USE_NEW_ALPS_CODEPOINT`` (long)
  Uses the new ALPS codepoint.
  Command line: ``--tls-use-new-alps-codepoint``.

HTTP/2
------

``CURLOPT_HTTP2_PSEUDO_HEADERS_ORDER`` (string)
  Sets the order of the HTTP/2 pseudo-headers. The value must contain the letters
  ``m``, ``a``, ``s``, and ``p``, representing ``:method``, ``:authority``,
  ``:scheme``, and ``:path`` in the desired order of appearance in the HTTP/2 HEADERS
  frame. For example: ``masp``.
  Command line: ``--http2-pseudo-headers-order <order>``.

``CURLOPT_HTTP2_SETTINGS`` (string)
  Sets HTTP/2 settings frame keys and values, in the format ``1:v;2:v;3:v``. For
  example: ``1:65536;3:1000;4:6291456;6:262144``.
  Command line: ``--http2-settings <settings>``.

``CURLOPT_HTTP2_WINDOW_UPDATE`` (long)
  Sets the initial HTTP/2 window update value. For example: ``15663105``.
  Command line: ``--http2-window-update <integer>``.

``CURLOPT_HTTP2_STREAMS`` (string)
  Sets the initial streams settings for HTTP/2.
  Command line: ``--http2-streams <value>``.

``CURLOPT_HTTP2_NO_PRIORITY`` (long)
  Prevents curl-impersonate from setting the priority bit in the HTTP/2 HEADERS frame.
  Command line: ``--http2-no-priority``.

``CURLOPT_STREAM_EXCLUSIVE`` (long)
  Sets HTTP/2 stream exclusiveness as ``0`` or ``1``.
  Command line: ``--http2-stream-exclusive <0|1>``.

HTTP/3 and QUIC
---------------

``CURLOPT_HTTP3_PSEUDO_HEADERS_ORDER`` (string)
  Sets the order of the HTTP/3 pseudo-headers. The value must contain the letters
  ``m``, ``a``, ``s``, and ``p``, representing ``:method``, ``:authority``,
  ``:scheme``, and ``:path`` in the desired order of appearance in the HTTP/3 HEADERS
  frame. This is the HTTP/3 analogue of ``CURLOPT_HTTP2_PSEUDO_HEADERS_ORDER``.
  Command line: ``--http3-pseudo-headers-order <order>``.

``CURLOPT_HTTP3_SETTINGS`` (string)
  Sets HTTP/3 settings frame keys and values, in the format ``1:v;6:v;7:v``.
  Command line: ``--http3-settings <settings>``.

``CURLOPT_QUIC_TRANSPORT_PARAMETERS`` (string)
  Sets QUIC transport parameters, in the format ``id:value;id:value``.
  Command line: ``--quic-transport-params <params>``.

``CURLOPT_HTTP3_SIG_HASH_ALGS`` (string)
  Sets signature hash algorithms for HTTP/3 QUIC TLS. If set, this is used instead of
  ``CURLOPT_SSL_SIG_HASH_ALGS`` for QUIC connections.
  Command line: ``--http3-sig-hash-algs <algorithm list>``.

``CURLOPT_HTTP3_TLS_EXTENSION_ORDER`` (string)
  Sets TLS extension order for HTTP/3 QUIC TLS. If set, this is used instead of
  ``CURLOPT_TLS_EXTENSION_ORDER`` for QUIC connections.
  Command line: ``--http3-tls-extension-order <order>``.

Proxy and Cookies
-----------------

``CURLOPT_PROXY_CREDENTIAL_NO_REUSE`` (long)
  Prevents reuse of TLS sessions or connections across different proxy credentials.
  Command line: ``--proxy-credential-no-reuse``.

``CURLOPT_SPLIT_COOKIES`` (long)
  Splits cookies into separate ``Cookie:`` headers. For http/1.1, Cookies are joined as
  a single header. For http/2 and http/3, Cookies are separated for better compression
  rate.
  Command line: ``--split-cookies`` / ``--no-split-cookies``.
