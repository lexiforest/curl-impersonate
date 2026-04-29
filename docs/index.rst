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
   fingerprints
   bindings
   api
   faq
   changelog
   dev
   pro

.. note::

   This documentation covers `lexiforest's fork <https://github.com/lexiforest/curl-impersonate>`_
   of curl-impersonate.


``curl-impersonate`` is a curl build that makes HTTP requests look like they came from a
real browser. It can impersonate recent versions of Chrome, Edge, Safari, Firefox, and
Tor.

You can use curl-impersonate either as a command-line tool, much like regular curl, or
as a library in place of regular libcurl.

The project supports all major platforms, including macOS, Linux, Windows, Android, and
iOS. It can also be built on systems such as BSD with minor changes, although those
platforms are not officially supported.

Compared with upstream curl, this distribution includes patched BoringSSL, Chrome's TLS
library, and a few other patched components to reproduce browser TLS and HTTP
fingerprints as closely as possible.

HTTP/3 is enabled by default in this distribution.

Join our `community on discord <https://discord.gg/kJqMHHgdn2>`_.

Sponsors
--------

Bypass Cloudflare with API
~~~~~~~~~~~~~~~~~~~~~~~~~~

.. image:: https://raw.githubusercontent.com/lexiforest/curl_cffi/main/assets/yescaptcha.png
   :width: 149
   :alt: YesCaptcha
   :target: https://yescaptcha.com/i/stfnIO

`Yescaptcha <https://yescaptcha.com/i/stfnIO>`_ is a proxy service that bypasses
Cloudflare and uses an API to obtain verified cookies such as ``cf_clearance``. Click
`here <https://yescaptcha.com/i/stfnIO>`_ to register.

You can also click `here <https://buymeacoffee.com/yifei>`_ to buy me a coffee.

Residential Proxies
~~~~~~~~~~~~~~~~~~~

.. image:: https://raw.githubusercontent.com/lexiforest/curl_cffi/main/assets/thordata.png
   :width: 149
   :alt: Thordata
   :target: https://www.thordata.com/?ls=github&lk=curl_

`Thordata <https://www.thordata.com/?ls=github&lk=curl_>`_ is a reliable and
cost-effective proxy provider. It helps enterprises and developers collect public web
data with stable, efficient, and compliant global proxy IP services. Register for a free
trial of `residential proxies <https://www.thordata.com/?ls=github&lk=curl_>`_ and
receive 2000 free SERP API calls.


Indices and tables
==================

* :ref:`genindex`
* :ref:`modindex`
* :ref:`search`
