.. curl-impersonate documentation master file, created by
   sphinx-quickstart on Sat Feb 17 22:22:59 2024.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

curl-impersonate(lexiforest's fork)
=========================

.. toctree::
   :maxdepth: 2
   :caption: Contents:

   install
   building
   quick_start
   advanced
   bindings
   api
   faq
   changelog
   dev
   pro

`Discuss on Telegram`_


.. note::

   This is the `lexiforest's fork <https://github.com/lexiforest/curl-impersonate>`_ of curl-impersonate.


curl-impersonate is a curl build that lets you send HTTP requests that look like a browser's.
curl-impersonate can impersonate recent versions of Chrome, Edge, Safari, Firefox & Tor.

curl-impersonate can be used either as a command line tool, similar to the regular curl,
or as a library that can be integrated instead of the regular libcurl.

curl-impersonate supports Windows, Linux and macOS. It can be compiled on other systems
like BSD with minor modification, but we do not officially support them for now.

The is a patched distribution of (lib)curl, with patched BoringSSL, Chrome's TLS library.
It is based on a series of patches that adds support for some additional TLS extensions
and modified HTTP/2 settings that make it look like a browser.

This distribution also has http/3 enabled by default.

Join our `community on telegram <https://t.me/+lL9n33eZp480MGM1>`_.

Sponsors
--------

Bypass Cloudflare with API
~~~~~~~~~~~~~~~~~~~~~~~~~~

.. image:: https://raw.githubusercontent.com/lexiforest/curl_cffi/main/assets/yescaptcha.png
   :width: 149
   :alt: YesCaptcha
   :target: https://yescaptcha.com/i/stfnIO

`Yescaptcha <https://yescaptcha.com/i/stfnIO>`_ is a proxy service that bypasses Cloudflare
and uses the API interface to obtain verified cookies (e.g. ``cf_clearance``). Click
`here <https://yescaptcha.com/i/stfnIO>`_ to register.

Easy Captcha Bypass for Scraping
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. image:: https://raw.githubusercontent.com/lexiforest/curl_cffi/main/assets/capsolver.jpg
   :width: 170
   :alt: Capsolver
   :target: https://dashboard.capsolver.com/passport/register?inviteCode=0FLEay4iroNC

`CapSolver <https://dashboard.capsolver.com/passport/register?inviteCode=0FLEay4iroNC>`_
is an AI-powered tool that easily bypasses Captchas, allowing uninterrupted access to
public data. It supports a variety of Captchas and works seamlessly with ``curl_cffi``,
Puppeteer, Playwright, and more. Fast, reliable, and cost-effective. Plus, ``curl_cffi``
users can use the code **"CURL"** to get an extra 6% balance! and register
`here <https://dashboard.capsolver.com/passport/register?inviteCode=0FLEay4iroNC>`_

You can also click `here <https://buymeacoffee.com/yifei>`_ to buy me a coffee.


Indices and tables
==================

* :ref:`genindex`
* :ref:`modindex`
* :ref:`search`
