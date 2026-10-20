## Browser signatures database

Each .yaml contains the signatures of a different browser.

Each signature refers to the browser's behavior upon browsing to a site
not cached or visited before.

Signatures normally contain the parameters in the TLS client hello message and
the browser's HTTP/2 HEADERS and SETTINGS frames. Profiles with HTTP/3 support
also include normalized QUIC transport parameters and QUIC TLS fields under
`http3`.

Generated files may instead contain partial expectations derived from profile
options. `tls_client_hello.partial: true` checks known cipher and extension
fields without inventing packet lengths, record versions, or session ID lengths.
An HTTP/3 section contains the available settings, pseudo-header order, QUIC
transport parameters, and headers; QUIC TLS capture fields are only checked
when supplied.

Use [`scripts/generate_fingerprints.py`](../../scripts/generate_fingerprints.py)
to generate or replace `<target>.yaml` files. Explicit TLS and HTTP/3 captures
in the input take precedence over derived expectations. See the
[development guide](../../docs/dev.rst) for the input format and workflow.
