# Using libcurl-impersonate

Documentation for using libcurl-impersonate is currently on the [main page](https://github.com/lexiforest/curl-impersonate#libcurl-impersonate)

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
