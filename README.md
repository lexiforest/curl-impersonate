# curl-impersonate ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") ![Edge](https://raw.githubusercontent.com/alrra/browser-logos/main/src/edge/edge_24x24.png "Edge") ![Safari](https://github.com/alrra/browser-logos/blob/main/src/safari/safari_24x24.png "Safari") ![Firefox](https://github.com/alrra/browser-logos/blob/main/src/firefox/firefox_24x24.png "Firefox") ![Tor](https://github.com/alrra/browser-logos/blob/main/src/tor/tor_24x24.png "Tor")

[![Build and test](https://github.com/lexiforest/curl-impersonate/actions/workflows/build-and-test.yml/badge.svg)](https://github.com/lexiforest/curl-impersonate/actions/workflows/build-and-test.yml)
[![Docker images](https://github.com/lexiforest/curl-impersonate/actions/workflows/build-push-docker.yml/badge.svg)](https://github.com/lexiforest/curl-impersonate/actions/workflows/build-push-docker.yml)

> [!NOTE]
> This is a (slightly) more active fork of [curl-impersonate](https://github.com/lwthiker/curl-impersonate).
> With the following enhancements:
>
> 1. Encrypted Client Hello(ECH) support introduced in Chrome 119.
> 2. ZSTD compression support introduced in Chrome 123.
> 3. X25519Kyber768/X25519MLKEM curves introduced in Chrome 124 and 130.
> 4. More options for impersonating Akamai http/2 fingerprints, especially for Safari.
> 5. Upgrade to more recent version of curl, 8.15.0 as of August, 2025.
> 6. Ability to change extension orders and enable/disable TLS grease.
> 7. Single binary to support Chrome, Safari and Firefox.
> 8. Built with http/3 enabled, http/3 and quic fingerprints are also supported.
> 9. A user-friendly Python binding: [curl_cffi](https://github.com/lexiforest/curl_cffi).
> 10. More prebuilt binaries, including Windows, Arm, and even RISC-V!
> 11. Commercial support at [impersonate.pro](https://impersonate.pro).

> [!WARNING]
> Breaking changes on v1.0, see release page for details.

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

| Browser | Version | OS | Target name | Wrapper script | H3 fingerprints |
| --- | --- | --- | --- | --- | --- |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 99 | Windows 10 | `chrome99` | [curl_chrome99](bin/curl_chrome99) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 100 | Windows 10 | `chrome100` | [curl_chrome100](bin/curl_chrome100) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 101 | Windows 10 | `chrome101` | [curl_chrome101](bin/curl_chrome101) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 104 | Windows 10 | `chrome104` | [curl_chrome104](bin/curl_chrome104) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 107 | Windows 10 | `chrome107` | [curl_chrome107](bin/curl_chrome107) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 110 | Windows 10 | `chrome110` | [curl_chrome110](bin/curl_chrome110) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 116 | Windows 10 | `chrome116` | [curl_chrome116](bin/curl_chrome116) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 119 | macOS Sonoma | `chrome119` | [curl_chrome119](bin/curl_chrome119) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 120 | macOS Sonoma | `chrome120` | [curl_chrome120](bin/curl_chrome120) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 123 | macOS Sonoma | `chrome123` | [curl_chrome123](bin/curl_chrome123) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 124 | macOS Sonoma | `chrome124` | [curl_chrome124](bin/curl_chrome124) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 131 | macOS Sonoma | `chrome131` | [curl_chrome131](bin/curl_chrome131) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 133 | macOS Sequoia | `chrome133a` | [curl_chrome133a](bin/curl_chrome133a) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 136 | macOS Sequoia | `chrome136` | [curl_chrome136](bin/curl_chrome136) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 142 | macOS Tahoe | `chrome142` | [curl_chrome142](bin/curl_chrome142) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 145 | macOS Tahoe | `chrome145` | [curl_chrome145](bin/curl_chrome145) | ✅ |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 99 | Android 12 | `chrome99_android` | [curl_chrome99_android](bin/curl_chrome99_android) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 131 | Android 14 | `chrome131_android` | [curl_chrome131_android](bin/curl_chrome131_android) |
| ![Edge](https://raw.githubusercontent.com/alrra/browser-logos/main/src/edge/edge_24x24.png "Edge") | 99 | Windows 10 | `edge99` | [curl_edge99](bin/curl_edge99) |
| ![Edge](https://raw.githubusercontent.com/alrra/browser-logos/main/src/edge/edge_24x24.png "Edge") | 101 | Windows 10 | `edge101` | [curl_edge101](bin/curl_edge101) |
| ![Safari](https://github.com/alrra/browser-logos/blob/main/src/safari/safari_24x24.png "Safari") | 15.3 | macOS Big Sur | `safari153` | [curl_safari153](bin/curl_safari153) |
| ![Safari](https://github.com/alrra/browser-logos/blob/main/src/safari/safari_24x24.png "Safari") | 15.5 | macOS Monterey | `safari155` | [curl_safari155](bin/curl_safari155) |
| ![Safari](https://github.com/alrra/browser-logos/blob/main/src/safari/safari_24x24.png "Safari") | 17.0 | macOS Sonoma | `safari170` | [curl_safari170](bin/curl_safari170) |
| ![Safari](https://github.com/alrra/browser-logos/blob/main/src/safari/safari_24x24.png "Safari") | 17.2 | iOS 17.2 | `safari172_ios` | [curl_safari172_ios](bin/curl_safari172_ios) |
| ![Safari](https://github.com/alrra/browser-logos/blob/main/src/safari/safari_24x24.png "Safari") | 18.0 | macOS Sequoia | `safari180` | [curl_safari180](bin/curl_safari180) |
| ![Safari](https://github.com/alrra/browser-logos/blob/main/src/safari/safari_24x24.png "Safari") | 18.0 | iOS 18.0 | `safari180_ios` | [curl_safari184_ios](bin/curl_safari180_ios) |
| ![Safari](https://github.com/alrra/browser-logos/blob/main/src/safari/safari_24x24.png "Safari") | 18.4 | macOS Sequoia | `safari184` | [curl_safari184](bin/curl_safari184) |
| ![Safari](https://github.com/alrra/browser-logos/blob/main/src/safari/safari_24x24.png "Safari") | 18.4 | iOS 18.4 | `safari184_ios` | [curl_safari180_ios](bin/curl_safari184_ios) |
| ![Safari](https://github.com/alrra/browser-logos/blob/main/src/safari/safari_24x24.png "Safari") | 26.0 | macOS Tahoe | `safari260` | [curl_safari260](bin/curl_safari260) |
| ![Safari](https://github.com/alrra/browser-logos/blob/main/src/safari/safari_24x24.png "Safari") | 26.0 | iOS 26.0 | `safari260_ios` | [curl_safari260_ios](bin/curl_safari260_ios) |
| ![Firefox](https://github.com/alrra/browser-logos/blob/main/src/firefox/firefox_24x24.png "Firefox") | 133.0 | macOS Sonoma | `firefox133` | [curl_firefox133](bin/curl_firefox133) |
| ![Firefox](https://github.com/alrra/browser-logos/blob/main/src/firefox/firefox_24x24.png "Firefox") | 135.0 | macOS Sonoma | `firefox135` | [curl_firefox135](bin/curl_firefox135) |
| ![Firefox](https://github.com/alrra/browser-logos/blob/main/src/firefox/firefox_24x24.png "Firefox") | 144.0 | macOS Tahoe | `firefox144` | [curl_firefox144](bin/curl_firefox144) |
| ![Firefox](https://github.com/alrra/browser-logos/blob/main/src/firefox/firefox_24x24.png "Firefox") | 147.0 | macOS Tahoe | `firefox147` | [curl_firefox147](bin/curl_firefox147) | ✅ |
| ![Tor](https://github.com/alrra/browser-logos/blob/main/src/tor/tor_24x24.png "Tor") | 14.5 | macOS Sonoma | `tor145` | [curl_tor145](bin/curl_tor145) |

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

You can also use the following docker images:

- [lexiforest/curl-impersonate](https://hub.docker.com/r/lexiforest/curl-impersonate/tags)
- [lexiforest/curl-impersonate:alpine](https://hub.docker.com/r/lexiforest/curl-impersonate/tags)

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
* [patches](patches/) - Patches for building `curl-impersonate`.
    * [curl.patch](patches/curl.patch) - The main patch that makes curl use the same TLS extensions as browsers. Also makes curl compile statically with libnghttp2 etc.
    * [boringssl.patch](patches/boringssl.patch) - The boringssl patch that tweaks boringssl behaviors to the same as browsers.
* [bin](bin/) - Shortcut scripts for easier use.
    * [curl_chrome110](bin/curl_chrome110), [curl_chrome124](bin/curl_chrome124) - Wrapper scripts that launch `curl-impersonate` with the correct flags.
* [win](win) - Scripts for building the Windows version of `curl-impersonate`, which is quite different from `*nix`.
    * [win/bin](win/bin/) - Shortcut scripts for easier use on Windows.
* [zigshim](zigshim) - We use the awesome `zig` toolchain to bring `curl-impersonate` to more archs on Linux.
* [docker](docker) - Debian and alpine dockerfiles for this project.

Other files of interest:

* [tests/signatures](tests/signatures) - YAML database of known browser signatures that can be impersonated.

## Contributing

If you'd like to help, please check out the [open issues in the origional repo](https://github.com/lwthiker/curl-impersonate/issues) and [open issues here](https://github.com/lexiforest/curl-impersonate/issues). You can open a pull request with your changes. Note that some of the upstream issues have been fixed.

This repository contains the build process for `curl-impersonate`. The actual patches to `curl` are maintained in a [separate repository](https://github.com/lexiforest/curl-chrome) forked from lwthiker's fork of the upstream curl. The changes are maintained in the [impersonate-chrome](https://github.com/lexiforest/curl-chrome/tree/impersonate-chrome) branch.

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

### Hyper Solutions

<a href="https://hypersolutions.co/?utm_source=github&utm_medium=readme&utm_campaign=curl_cffi" target="_blank"><img src="https://raw.githubusercontent.com/lexiforest/curl_cffi/main/assets/hypersolutions.png" height="47" width="149"></a>

TLS fingerprinting alone isn't enough for modern bot protection. [Hyper Solutions](https://hypersolutions.co?utm_source=github&utm_medium=readme&utm_campaign=curl_cffi) provides the missing piece - API endpoints that generate valid antibot tokens for:

Akamai • DataDome • Kasada • Incapsula

No browser automation. Just simple API calls that return the exact cookies and headers these systems require.

🚀 [Get Your API Key](https://hypersolutions.co?utm_source=github&utm_medium=readme&utm_campaign=curl_cffi) | 📖 [Docs](https://docs.justhyped.dev) | 💬 [Discord](https://discord.gg/akamai)

### Recall.ai - API for meeting recordings

<a href="https://www.recall.ai/?utm_source=github&utm_medium=sponsorship&utm_campaign=lexiforest-curl_cffi" target="_blank"><img src="https://cdn.prod.website-files.com/620d732b1f1f7b244ac89f0e/66b294e51ee15f18dd2b171e_recall-logo.svg" alt="Recall.ai" height="47" width="149"></a>

If you’re looking for a meeting recording API, consider checking out [Recall.ai](https://www.recall.ai/?utm_source=github&utm_medium=sponsorship&utm_campaign=lexiforest-curl_cffi), an API that records Zoom, Google Meet, Microsoft Teams, in-person meetings, and more.

### Residential Proxies

<a href="https://www.thordata.com/?ls=github&lk=curl_cffi" target="_blank"><img src="https://raw.githubusercontent.com/lexiforest/curl_cffi/main/assets/thordata.png" alt="Thordata" height="126" width="240"></a>

Thordata: A reliable and cost-effective proxy service provider. One-click collection of public network data, providing enterprises and developers with stable, efficient, and compliant global proxy IP services. Register for a free trial of [residential proxies](https://www.thordata.com/products/residential-proxies/?ls=github&lk=curl_cffi) and receive 2000 free SERP API calls.
