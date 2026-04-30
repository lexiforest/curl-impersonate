Quick Start
***********

On the command line
===================

You can run curl-impersonate from the command line just like regular curl. Since it is a
modified curl build, all of the original flags and command-line options are supported.

For example:

.. code-block:: bash

    curl-impersonate -v -L https://example.com

However, running the binary directly does not produce the same TLS and HTTP/2 signatures
as the impersonated browsers. To solve this, the project provides *wrapper scripts* that
launch the binaries with the correct command-line flags. For example:

.. code-block:: bash

    curl_chrome104 -v -L https://example.com

This produces a signature identical to Chrome 104. You can add your own command-line
flags and they will be passed through to curl. However, some flags change curl's TLS
signature.

The full list of wrapper scripts is available on the :doc:`api`.

Changing the HTTP headers
-------------------------

The wrapper scripts set a default group of HTTP headers such as ``User-Agent`` and
``Accept-Encoding``. These headers were chosen to match the browser's default headers
for a first visit to a website, including header order.

In many situations, you may want to change the headers, change their order, or add new
ones. The safest approach today is to modify the wrapper scripts directly. Otherwise,
you may end up with duplicate headers or the wrong header order.

How the wrapper scripts work
----------------------------

Let's look at the ``curl_chrome104`` wrapper script. Understanding how it works is
helpful when you need tighter control over the final signature.

The important part of the script is:

.. code-block:: bash

    "$dir/curl-impersonate" \
        --ciphers TLS_AES_128_GCM_SHA256,TLS_AES_256_GCM_SHA384,TLS_CHACHA20_POLY1305_SHA256,ECDHE-ECDSA-AES128-GCM-SHA256,ECDHE-RSA-AES128-GCM-SHA256,ECDHE-ECDSA-AES256-GCM-SHA384,ECDHE-RSA-AES256-GCM-SHA384,ECDHE-ECDSA-CHACHA20-POLY1305,ECDHE-RSA-CHACHA20-POLY1305,ECDHE-RSA-AES128-SHA,ECDHE-RSA-AES256-SHA,AES128-GCM-SHA256,AES256-GCM-SHA384,AES128-SHA,AES256-SHA \
        -H 'sec-ch-ua: "Chromium";v="104", " Not A;Brand";v="99", "Google Chrome";v="104"' \
        -H 'sec-ch-ua-mobile: ?0' \
        -H 'sec-ch-ua-platform: "Windows"' \
        -H 'Upgrade-Insecure-Requests: 1' \
        -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/104.0.0.0 Safari/537.36' \
        -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9' \
        -H 'Sec-Fetch-Site: none' \
        -H 'Sec-Fetch-Mode: navigate' \
        -H 'Sec-Fetch-User: ?1' \
        -H 'Sec-Fetch-Dest: document' \
        -H 'Accept-Encoding: gzip, deflate, br' \
        -H 'Accept-Language: en-US,en;q=0.9' \
        --http2 --compressed \
        --tlsv1.2 --no-npn --alps \
        --cert-compression brotli \
        "$@"

The most important flags are:

* ``--ciphers`` controls the cipher list, which is an important part of the TLS ClientHello
  message. The ciphers were chosen to match Chrome's.
* The multiple ``-H`` flags set the HTTP headers. You may want to modify these in many
  scenarios where other HTTP headers are required.
* ``--tlsv1.2`` sets the minimal TLS version, which is part of the TLS client hello
  message, to TLS 1.2.
* ``--no-npn`` disables the NPN TLS extension.
* ``--alps`` enables the ALPS TLS extension. This flag was added for this project.
* ``--cert-compression`` enables TLS certificate compression used by Chrome. This flag
  was added for this project.

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

You can call it with a target name such as ``chrome123``. It will internally set all the
options and headers that the wrapper scripts would otherwise apply. If
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

Warning on HTTP/3
-----------------

Avoid using ``CURL_IMPERSONATE`` with HTTP/3. The environment hook calls
``curl_easy_impersonate()`` very early, during easy handle initialization or reset,
before later HTTP version configuration may be applied. This can lead to suboptimal HTTP/3
behavior.

Prefer explicit impersonation setup:

* On the command line, use ``--http3`` or ``--http3-only`` together with
  ``--impersonate``.
* With libcurl, set ``CURLOPT_HTTP_VERSION`` first, then call
  ``curl_easy_impersonate()``.

