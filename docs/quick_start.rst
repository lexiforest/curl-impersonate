Usage
***********

On the command line
==============================================

curl-impersonate can run from the command line just like the regular curl tool.
Since it is just a modified curl build, all the original flags and command-line options
are supported.

For example, it can run as follows:

.. code-block:: bash

    curl-impersonate -v -L https://wikipedia.org

However, by default, running the binaries as above will not produce the same TLS and
HTTP/2 signatures as the impersonated browsers. Rather, this project provides additional
*wrapper scripts* that launch these binaries with the correct set of command line flags
to produce the desired signatures. For example:

.. code-block:: bash

    curl_chrome104 -v -L https://wikipedia.org

will produce a signature identical to Chrome version 104. You can add command line flags
and they will be passed on to curl. However, some flags change curl's TLS signature. See
below for more details.

The full list of wrapper scripts is available on the :doc:`api`.

Changing the HTTP headers
-------------------------

The wrapper scripts use a certain set of HTTP headers such as `User-Agent`, `Accept-Encoding`
and a few more. These headers were chosen to be identical to the default set of headers
used by the browser upon requesting an unvisited website. The order of the headers was
chosen to match as well.

In many different scenarios you may wish to change the headers, their order, or to add new ones.
To do so correctly, currently the best option is to modify the scripts.
Otherwise you may get duplicate headers or a wrong order of headers.

How the wrapper scripts work
----------------------------

Let's analyze the contents of the `curl_chrome104` wrapper script.
Understanding this can help in some scenarios where better control of the signature is needed.

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

The important flags are as follows:

* `--ciphers` controls the cipher list, an important part of the TLS client hello message. The ciphers were chosen to match Chrome's.
* The multiple `-H` flags set the HTTP headers. You may want to modify these in many scenarios where other HTTP headers are required.
* `--tlsv1.2` sets the minimal TLS version, which is part of the TLS client hello message, to TLS1.2.
* `--no-npn` disables to NPN TLS extension.
* `--alps` enables the ALPS TLS extension. This flag was added for this project.
* `--cert-compression` enables TLS certificate compression used by Chrome. This flag was added for this project.

## Flags that modify the TLS signature

The following flags are known to affect the TLS signature of curl.
Using them in addition to the flags in the wrapper scripts may produce a signature that does not match the browser.

`--ciphers`, `--curves`, `--no-npn`, `--no-alpn`, `--tls-max`, `--tls13-ciphers`, `--tlsv1.0`, `--tlsv1.1`, `--tlsv1.2`, `--tlsv1.3`, `--tlsv1`

Using libcurl-impersonate
=========================

`libcurl-impersonate.so` is libcurl compiled with the same changes as the command line `curl-impersonate`.

It has an additional API function:

```c
CURLcode curl_easy_impersonate(struct Curl_easy *data, const char *target,
                               int default_headers);
```

You can call it with the target names, e.g. `chrome123`, and it will internally set all the options and headers that are otherwise set by the wrapper scripts.
If `default_headers` is set to 0, the built-in list of  HTTP headers will not be set, and the user is expected to provide them instead using the regular [`CURLOPT_HTTPHEADER`](https://curl.se/libcurl/c/CURLOPT_HTTPHEADER.html) libcurl option.

Calling the above function sets the following libcurl options:

* `CURLOPT_HTTP_VERSION`
* `CURLOPT_SSLVERSION`,
* `CURLOPT_SSL_CIPHER_LIST`,
* `CURLOPT_SSL_EC_CURVES`,
* `CURLOPT_SSL_ENABLE_NPN`,
* `CURLOPT_SSL_ENABLE_ALPN`
* `CURLOPT_HTTPBASEHEADER`, if `default_headers` is non-zero (this is a non-standard HTTP option created for this project).
* `CURLOPT_HTTP2_PSEUDO_HEADERS_ORDER`, sets http2 pseudo header order, for exmaple: `masp` (non-standard HTTP/2 options created for this project).
* `CURLOPT_HTTP2_SETTINGS` sets the settings frame values, for example `1:65536;3:1000;4:6291456;6:262144` (non-standard HTTP/2 options created for this project).
* `CURLOPT_HTTP2_WINDOW_UPDATE` sets intial window update value for http2, for example `15663105` (non-standard HTTP/2 options created for this project).
* `CURLOPT_SSL_ENABLE_ALPS`, `CURLOPT_SSL_SIG_HASH_ALGS`, `CURLOPT_SSL_CERT_COMPRESSION`, `CURLOPT_SSL_ENABLE_TICKET` (non-standard TLS options created for this project).
* `CURLOPT_SSL_PERMUTE_EXTENSIONS`, whether to permute extensions like Chrome 110+. (non-standard TLS options created for this project).
* `CURLOPT_TLS_GREASE`, whether to enable the grease behavior. (non-standard TLS options created for this project).
* `CURLOPT_TLS_EXTENSION_ORDER`, explicit order or TLS extensions, in the format of `0-5-10`. (non-standard TLS options created for this project).

Note that if you call `curl_easy_setopt()` later with one of the above it will override the options set by `curl_easy_impersonate()`.

### Using CURL_IMPERSONATE env var
If your application uses `libcurl` already, you can replace the existing library at runtime with `LD_PRELOAD` (Linux only). You can then set the `CURL_IMPERSONATE` env var. For example:

    LD_PRELOAD=/path/to/libcurl-impersonate.so CURL_IMPERSONATE=chrome116 my_app

The `CURL_IMPERSONATE` env var has two effects:

* `curl_easy_impersonate()` is called automatically for any new curl handle created by `curl_easy_init()`.
* `curl_easy_impersonate()` is called automatically after any `curl_easy_reset()` call.

This means that all the options needed for impersonation will be automatically set for any curl handle.

If you need precise control over the HTTP headers, set `CURL_IMPERSONATE_HEADERS=no` to disable the built-in list of HTTP headers, then set them yourself with `curl_easy_setopt()`. For example:

    LD_PRELOAD=/path/to/libcurl-impersonate.so CURL_IMPERSONATE=chrome116 CURL_IMPERSONATE_HEADERS=no my_app

Note that the `LD_PRELOAD` method will NOT WORK for `curl` itself because the curl tool overrides the TLS settings. Use the wrapper scripts instead.

### Notes on dependencies 

If you intend to copy the self-compiled artifacts to another system, or use the [Pre-compiled binaries](#pre-compiled-binaries) provided by the project, make sure that all the additional dependencies are met on the target system as well. 
In particular, see the [note about the Firefox version](INSTALL.md#a-note-about-the-firefox-version).

List of options
