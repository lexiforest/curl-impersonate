.. curl-impersonate documentation master file, created by
   sphinx-quickstart on Sat Feb 17 22:22:59 2024.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

curl-impersonate (lexiforest's fork)
====================================

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

.. note::

   This is the `lexiforest's fork <https://github.com/lexiforest/curl-impersonate>`_ of curl-impersonate.


``curl-impersonate`` is a curl build that lets you send HTTP requests that look like a
browser's. curl-impersonate can impersonate recent versions of Chrome, Edge, Safari,
Firefox & Tor.

curl-impersonate can be used either as a command line tool, similar to the regular curl,
or as a library that can be integrated instead of the regular libcurl.

All major OSes, including macOS, Linux, Windows, Android and iOS are supported. It can
also be compiled on other systems like BSD with minor modification, but we do not
officially support them for now.

Compared to vanilla curl, this is a patched distribution with patched BoringSSL,
Chrome's TLS library and a few other patched components for exact browser TLS & HTTP
fingerprints impersonation.

In this distribution, http/3 is enabled by default.

Join our `community on discord <https://discord.gg/kJqMHHgdn2>`_.

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

You can also click `here <https://buymeacoffee.com/yifei>`_ to buy me a coffee.

Residential Proxies
~~~~~~~~~~~~~~~~~~~

.. image:: https://raw.githubusercontent.com/lexiforest/curl_cffi/main/assets/thordata.png
   :width: 149
   :alt: Thordata
   :target: https://www.thordata.com/?ls=github&lk=curl_

`Thordata <https://www.thordata.com/?ls=github&lk=curl_>`_: A reliable and cost-effective proxy service provider. One-click collection of public network data, providing enterprises and developers with stable, efficient, and compliant global proxy IP services. Register for a free trial of `residential proxies <https://www.thordata.com/?ls=github&lk=curl_>`_ and receive 2000 free SERP API calls.


Indices and tables
==================

* :ref:`genindex`
* :ref:`modindex`
* :ref:`search`
