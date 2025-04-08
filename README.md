# curl-impersonate ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") ![Edge](https://raw.githubusercontent.com/alrra/browser-logos/main/src/edge/edge_24x24.png "Edge") ![Safari](https://github.com/alrra/browser-logos/blob/main/src/safari/safari_24x24.png "Safari") ![Firefox](https://github.com/alrra/browser-logos/blob/main/src/firefox/firefox_24x24.png "Firefox")

[![Build and test](https://github.com/lexiforest/curl-impersonate/actions/workflows/build-and-test-make.yml/badge.svg)](https://github.com/lexiforest/curl-impersonate/actions/workflows/build-and-test-make.yml)
[![Docker images](https://github.com/lexiforest/curl-impersonate/actions/workflows/build-and-test-docker.yml/badge.svg)](https://github.com/lexiforest/curl-impersonate/actions/workflows/build-and-test-docker.yml)

> [!NOTE]
> This is a (slightly) more active fork of [curl-impersonate](https://github.com/lwthiker/curl-impersonate).
> With the following enhancements:
>
> 1. Encrypted Client Hello(ECH) support introduced in Chrome 119.
> 2. ZSTD compression support introduced in Chrome 123.
> 3. X25519Kyber768/X25519MLKEM curves introduced in Chrome 124 and 130.
> 4. More options for impersonating Akamai http/2 fingerprints, especially for Safari.
> 5. Upgrade to more recent version of curl, 8.13.0 as of April, 2025.
> 6. Ability to change extension orders and enable/disable TLS grease.
> 7. Single binary to support Chrome, Safari and Firefox.
> 8. (In progress) Built with http/3 enabled.
> 9. A user-friendly Python binding: [curl_cffi](https://github.com/lexiforest/curl_cffi).
> 10. More prebuilt binaries, including Windows, Arm, and even RISC-V!
> 11. Commercial support at [impersonate.pro](https://impersonate.pro).


A special build of [curl](https://github.com/curl/curl) that can impersonate the four
major browsers: Chrome, Edge, Safari and Firefox. `curl-impersonate` is able to perform
TLS and HTTP handshakes that are identical to that of a real browser.

`curl-impersonate` can be used either as a command line tool, similar to the regular
curl, or as a library that can be integrated instead of the regular libcurl. See
[Usage](#basic-usage) below.

## Why?

When you use an HTTP client with a TLS website, it first performs a TLS handshake. The
first message of that handshake is called Client Hello. The Client Hello message that
most HTTP clients and libraries produce differs drastically from that of a real browser.

If the server uses HTTP/2, then in addition to the TLS handshake there is also an HTTP/2
handshake where various settings are exchanged. The settings that most HTTP clients and
libraries use differ as well from those of any real browsers.

For these reasons, some web services use the TLS and HTTP handshakes to fingerprint
which client is accessing them, and then present different content for different clients.
These methods are known as [TLS fingerprinting](https://lwthiker.com/networks/2022/06/17/tls-fingerprinting.html)
and [HTTP/2 fingerprinting](https://lwthiker.com/networks/2022/06/17/http2-fingerprinting.html)
respectively. Their widespread use has led to the web becoming less open, less private
and much more restrictive towards specific web clients.

With the modified curl in this repository, the TLS and HTTP handshakes look *exactly*
like those of a real browser.

## How?

To make this work, `curl` was patched significantly to resemble a browser. Specifically,
The modifications that were needed to make this work:

* Compiling with BoringSSL, Google's TLS library, which is used by Chrome and Safari.
* Modifying the way curl configures various TLS extensions and SSL options.
* Adding support for new TLS extensions.
* Changing the settings that curl uses for its HTTP/2 connections.
* Running curl with some non-default flags, for example `--ciphers`, `--curves` and some `-H` headers.

The resulting curl looks, from a network perspective, identical to a real browser.

Read the original technical description in the blog posts: [part a](https://lwthiker.com/reversing/2022/02/17/curl-impersonate-firefox.html), [part b](https://lwthiker.com/reversing/2022/02/20/impersonating-chrome-too.html). Much more has been added since then, but you get the general ideas :P.

## Supported browsers

The following browsers can be impersonated.

| Browser | Version | Build | OS | Target name | Wrapper script |
| --- | --- | --- | --- | --- | --- |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 99 | 99.0.4844.51 | Windows 10 | `chrome99` | [curl_chrome99](chrome/curl_chrome99) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 100 | 100.0.4896.75 | Windows 10 | `chrome100` | [curl_chrome100](chrome/curl_chrome100) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 101 | 101.0.4951.67 | Windows 10 | `chrome101` | [curl_chrome101](chrome/curl_chrome101) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 104 | 104.0.5112.81 | Windows 10 | `chrome104` | [curl_chrome104](chrome/curl_chrome104) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 107 | 107.0.5304.107 | Windows 10 | `chrome107` | [curl_chrome107](chrome/curl_chrome107) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 110 | 110.0.5481.177 | Windows 10 | `chrome110` | [curl_chrome110](chrome/curl_chrome110) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 116 | 116.0.5845.180 | Windows 10 | `chrome116` | [curl_chrome116](chrome/curl_chrome116) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 119 | 119.0.6045.199 | macOS Sonoma | `chrome119` | [curl_chrome119](chrome/curl_chrome119) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 120 | 120.0.6099.109 | macOS Sonoma | `chrome120` | [curl_chrome120](chrome/curl_chrome120) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 123 | 123.0.6312.124 | macOS Sonoma | `chrome123` | [curl_chrome123](chrome/curl_chrome123) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 124 | 124.0.6367.60 | macOS Sonoma | `chrome124` | [curl_chrome124](chrome/curl_chrome124) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 131 | 131.0.6778.86 | macOS Sonoma | `chrome131` | [curl_chrome131](chrome/curl_chrome131) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 133 | 133.0.6943.55 | macOS Sequoia | `chrome133a` | [curl_chrome131a](chrome/curl_chrome131a) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 99 | 99.0.4844.73 | Android 12 | `chrome99_android` | [curl_chrome99_android](chrome/curl_chrome99_android) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 131 | 131.0.6778.81 | Android 14 | `chrome131_android` | [curl_chrome131_android](chrome/curl_chrome131_android) |
| ![Edge](https://raw.githubusercontent.com/alrra/browser-logos/main/src/edge/edge_24x24.png "Edge") | 99 | 99.0.1150.30 | Windows 10 | `edge99` | [curl_edge99](chrome/curl_edge99) |
| ![Edge](https://raw.githubusercontent.com/alrra/browser-logos/main/src/edge/edge_24x24.png "Edge") | 101 | 101.0.1210.47 | Windows 10 | `edge101` | [curl_edge101](chrome/curl_edge101) |
| ![Safari](https://github.com/alrra/browser-logos/blob/main/src/safari/safari_24x24.png "Safari") | 15.3 | 16612.4.9.1.8 | MacOS Big Sur | `safari15_3` | [curl_safari15_3](chrome/curl_safari15_3) |
| ![Safari](https://github.com/alrra/browser-logos/blob/main/src/safari/safari_24x24.png "Safari") | 15.5 | 17613.2.7.1.8 | MacOS Monterey | `safari15_5` | [curl_safari15_5](chrome/curl_safari15_5) |
| ![Safari](https://github.com/alrra/browser-logos/blob/main/src/safari/safari_24x24.png "Safari") | 17.0 | unclear | MacOS Sonoma | `safari17_0` | [curl_safari17_0](chrome/curl_safari17_0) |
| ![Safari](https://github.com/alrra/browser-logos/blob/main/src/safari/safari_24x24.png "Safari") | 17.2 | unclear | iOS 17.2 | `safari17_2_ios` | [curl_safari17_2_ios](chrome/curl_safari17_2_ios) |
| ![Safari](https://github.com/alrra/browser-logos/blob/main/src/safari/safari_24x24.png "Safari") | 18.0 | unclear | MacOS Sequoia | `safari18_0` | [curl_safari18_0](chrome/curl_safari18_0) |
| ![Safari](https://github.com/alrra/browser-logos/blob/main/src/safari/safari_24x24.png "Safari") | 18.0 | unclear | iOS 18.0 | `safari18_0_ios` | [curl_safari18_0_ios](chrome/curl_safari18_0_ios) |
| ![Firefox](https://github.com/alrra/browser-logos/blob/main/src/firefox/firefox_24x24.png "Firefox") | 133.0 | 133.0.3 | macOS Sonoma | `firefox133` | [curl_firefox133](chrome/curl_firefox133) |
| ![Firefox](https://github.com/alrra/browser-logos/blob/main/src/firefox/firefox_24x24.png "Firefox") | 135.0 | 135.0.1 | macOS Sonoma | `firefox135` | [curl_firefox135](chrome/curl_firefox135) |

<small>
Notes:

1. Chromium-based browsers all share the same fingerprints, except for the `User-Agent` header and `sec-ch-ua-platform` header. They will not be updated unless this assumption changed. Use your own header if you need to impersonate `Edge`, `Chrome Android` etc.
2. The original Safari fingerprints in the upstream fork are [not correct](https://github.com/lwthiker/curl-impersonate/issues/215).
3. The version postfix `-a`(e.g. `chrome133a`) means that this is an alternative version, i.e. the fingerprint has not been officially updated by browser, but has been observed because of A/B testing.
</small>

~~This list is also available in the [browsers.json](browsers.json) file.()~~ Needs to be updated.

## Install

The simplest way is to download the prebuilt binaries from the [release page](https://github.com/lexiforest/curl-impersonate/releases).
If you want to build by yourself, please refer to the [INSTALL.md](INSTALL.md) and [docs/install.md](docs/02_install.md).

## Basic usage

For each supported browser there is a wrapper script that launches `curl-impersonate` with all the needed headers and flags. For example:

    curl_chrome123 https://www.wikipedia.org

You can add command line flags and they will be passed on to curl. However, some flags
change curl's TLS signature which may cause it to be detected.

To check the fingerprints are correct:

    curl_firefox133 https://tls.browserleaks.com/json

Please note that the wrapper scripts use a default set of HTTP headers. If you want to
change these headers, you may want to modify the wrapper scripts to fit your own purpose.

See the [docs](docs) for more options, including using `libcurl-impersonate` as a library.

## Documentation

More documentation is available in the [docs/](docs/) directory.

## Repository Contents

This repository contains these folders:
* [chrome](chrome) - Scripts and patches for building the Chrome version of `curl-impersonate`.
    * [curl_chrome110](chrome/curl_chrome110), [curl_chrome124](chrome/curl_chrome124) - Wrapper scripts that launch `curl-impersonate` with the correct flags.
    * [curl-impersonate.patch](chrome/patches/curl-impersonate.patch) - The main patch that makes curl use the same TLS extensions as Firefox. Also makes curl compile statically with libnghttp2.
    * [boringssl.patch](chrome/patches/boringssl.patch) - The boringssl patch that tweaks boringssl behaviors.
* [win](win) - Scripts for building the Windows version of `curl-impersonate`, which is quite different from `*nix`.
* [zigshim](zigshim) - We use the awesome `zig` toolchain to bring `curl-impersonate` to more archs on Linux.
* [docker](docker) - Debian and alpine dockerfiles for this project.

Other files of interest:

* [tests/signatures](tests/signatures) - YAML database of known browser signatures that can be impersonated.

## Contributing

If you'd like to help, please check out the [open issues in the origional repo](https://github.com/lwthiker/curl-impersonate/issues) and [open issues here](https://github.com/lexiforest/curl-impersonate/issues). You can open a pull request with your changes. Note that some of the upstream issues have been fixed.

This repository contains the build process for `curl-impersonate`. The actual patches to `curl` are maintained in a [separate repository](https://github.com/lexiforest/curl) forked from lwthiker's fork of the upstream curl. The changes are maintained in the [impersonate-chrome](https://github.com/lexiforest/curl/tree/impersonate-chrome) branch.

You may also need the [forked and patched](https://github.com/lexiforest/boringssl) BoringSSL.

## Acknowledgements

- Special thanks to @bjia56 for making cross compiling possible.
- Special thanks to @smaug2309 and @afulsamet for bring back the Windows build.
- Special thanks to @penumbra-x for the boringssl patch on firefox.

## Sponsors

### Bypass Cloudflare with API

<a href="https://yescaptcha.com/i/stfnIO" target="_blank"><img src="https://raw.githubusercontent.com/lexiforest/curl_cffi/main/assets/yescaptcha.png" alt="Yes Captcha!" height="47" width="149"></a>

Yescaptcha is a proxy service that bypasses Cloudflare and uses the API interface to
obtain verified cookies (e.g. `cf_clearance`). Click [here](https://yescaptcha.com/i/stfnIO)
to register: https://yescaptcha.com/i/stfnIO

------

### Easy Captcha Bypass for Scraping

<a href="https://www.capsolver.com/?utm_source=github&utm_medium=banner_repo&utm_campaign=scraping&utm_term=curl_cffi" target="_blank"><img src="https://raw.githubusercontent.com/lexiforest/curl_cffi/main/assets/capsolver.jpg" alt="CapSolver" height="50" width="178"></a>

[CapSolver](https://www.capsolver.com/?utm_source=github&utm_medium=banner_repo&utm_campaign=scraping&utm_term=curl_cffi)
is an AI-powered tool that easily bypasses Captchas, allowing uninterrupted access to
public data. It supports a variety of Captchas and works seamlessly with `curl_cffi`,
Puppeteer, Playwright, and more. Fast, reliable, and cost-effective. Plus, `curl_cffi`
users can use the code **"CURL"** to get an extra 6% balance! and register [here](https://dashboard.capsolver.com/passport/?utm_source=github&utm_medium=banner_repo&utm_campaign=scraping&utm_term=curl_cffi).

