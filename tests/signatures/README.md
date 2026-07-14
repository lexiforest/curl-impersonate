## Browser signatures database

Each .yaml contains the signatures of a different browser.

Each signature refers to the browser's behavior upon browsing to a site
not cached or visited before.

Signatures normally contain the parameters in the TLS client hello message and
the browser's HTTP/2 HEADERS and SETTINGS frames. Profiles with HTTP/3 support
also include normalized QUIC transport parameters and QUIC TLS fields under
`http3`.
