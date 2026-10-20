Quick Start
***********

On the command line
===================

You can run curl-impersonate from the command line just like regular curl. Since it is a
modified curl build, all of the original flags and command-line options are supported.

For example:

.. code-block:: bash

    curl-impersonate -v -L https://example.com

To select a browser profile, use a wrapper script or pass ``--impersonate``
directly:

.. code-block:: sh

    curl_chrome152 -v -L https://example.com
    curl-impersonate --compressed --impersonate chrome152 -v -L https://example.com

The wrapper selects the profile and enables response decompression. Extra
command-line flags are passed through to curl; some can change the resulting
TLS or HTTP signature. Running the binary without a profile does not select a
browser fingerprint.

See :doc:`fingerprints` for the full list of targets, OS variants, and HTTP/3
fingerprint support.

Changing the HTTP headers
-------------------------

Profiles supply default headers such as ``User-Agent`` and ``Accept-Encoding``.
Use ``-H`` to override a default header or add a new one:

.. code-block:: sh

    curl_chrome152 -H 'Accept-Language: en-US,en;q=0.9' \
        -H 'X-Example: value' https://example.com

Application headers replace matching profile defaults and additional headers
are appended. ``-H 'Header-Name:'`` suppresses a header. Changing these values
can change the fingerprint seen by the server.

HTTP/3
------

For profiles with dedicated HTTP/3 fingerprints:

.. code-block:: sh

    curl_chrome152 --http3 https://example.com
    curl_safari270_ios --http3-only https://example.com

``--http3`` permits fallback to HTTP/2 or HTTP/1.1, while ``--http3-only``
requires HTTP/3. The negotiated protocol determines which default headers are
used: HTTP/3-specific defaults when provided by the profile, otherwise the
regular defaults. ``-H`` overrides apply to either set.

How the wrapper scripts work
----------------------------

The ``curl_chrome152`` POSIX wrapper is:

.. code-block:: sh

    #!/bin/sh

    # Find the directory of this script
    dir=${0%/*}

    exec "$dir/curl-impersonate" --compressed --impersonate "chrome152" "$@"

The profile's TLS settings, protocol settings, and default headers live in
libcurl's preset table. The wrapper selects that preset with ``--impersonate``
and passes along your arguments. ``exec`` replaces the shell process with curl,
so signals and exit status propagate directly. Windows wrappers in ``win/bin``
select the same presets.

Flags that modify the TLS signature
-----------------------------------

The following flags are known to affect curl's TLS signature. If you use them in
addition to the flags in the wrapper scripts, the final signature may no longer match
the browser.

``--ciphers``, ``--curves``, ``--no-npn``, ``--no-alpn``, ``--tls-max``,
``--tls13-ciphers``, ``--tlsv1.0``, ``--tlsv1.1``, ``--tlsv1.2``,
``--tlsv1.3``, ``--tlsv1``

See :doc:`api` for the full list and per-option descriptions.

Using libcurl-impersonate
=========================

``libcurl-impersonate.so`` is libcurl compiled with the same changes as the command-line
``curl-impersonate`` tool.

It has an additional API function:

.. code-block:: c

    CURLcode curl_easy_impersonate(struct Curl_easy *data, const char *target,
                                   int default_headers);

You can call it with a target name such as ``chrome152``. It will internally set all the
profile options and headers selected by the wrapper scripts. If
``default_headers`` is set to ``0``, the built-in list of HTTP headers will not be set,
and you are expected to provide them yourself using the standard
`CURLOPT_HTTPHEADER <https://curl.se/libcurl/c/CURLOPT_HTTPHEADER.html>`_ libcurl option.

Calling the above function sets the usual curl protocol and TLS options together with
curl-impersonate's added ``CURLOPT_*`` extensions for browser-like TLS, HTTP/2, and
HTTP/3 fingerprints. See :doc:`api` for the full list and per-option descriptions.

If you later call ``curl_easy_setopt()`` with one of the options above, it overrides the
value previously set by ``curl_easy_impersonate()``.

Using ``CURL_IMPERSONATE``
--------------------------

If your application already uses ``libcurl``, you can replace the loaded library at
runtime with ``LD_PRELOAD`` on Linux. You can then set the ``CURL_IMPERSONATE``
environment variable. For example:

.. code-block:: bash

    LD_PRELOAD=/path/to/libcurl-impersonate.so CURL_IMPERSONATE=chrome116 my_app

The ``CURL_IMPERSONATE`` environment variable has two effects:

* ``curl_easy_impersonate()`` is called automatically for any new curl handle created by
  ``curl_easy_init()``.
* ``curl_easy_impersonate()`` is called automatically after any ``curl_easy_reset()``
  call.

This means all options required for impersonation are automatically applied to each curl
handle.

If you need precise control over the HTTP headers, set
``CURL_IMPERSONATE_HEADERS=no`` to disable the built-in list of HTTP headers, then set
them yourself with ``curl_easy_setopt()``. For example:

.. code-block:: bash

    LD_PRELOAD=/path/to/libcurl-impersonate.so CURL_IMPERSONATE=chrome116 CURL_IMPERSONATE_HEADERS=no my_app

Note that the ``LD_PRELOAD`` method does not work for ``curl`` itself because the curl
tool overrides the TLS settings. Use the wrapper scripts instead.

HTTP/3 with ``CURL_IMPERSONATE``
--------------------------------

The ``CURL_IMPERSONATE`` environment hook can be used with HTTP/3 in the same
way as with HTTP/2. Set ``CURLOPT_HTTP_VERSION`` (or use ``--http3``/
``--http3-only``) in the application or command line, and select the profile
through ``CURL_IMPERSONATE`` as usual.
