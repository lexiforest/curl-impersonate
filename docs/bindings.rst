Curl-impersonate bindings
=========================

With Python
-----------

You can use the Python binding
`curl_cffi <https://github.com/lexiforest/curl_cffi>`_, which works on Linux, macOS and
Windows.

With JavaScript
---------------

It is possible to make the ``node-libcurl`` package work with libcurl-impersonate
instead of libcurl. Instructions are currently available in
`Issue #80 <https://github.com/lwthiker/curl-impersonate/issues/80>`_.

With PHP
--------

It is possible to use libcurl-impersonate in PHP scripts instead of the original
libcurl. PHP loads libcurl dynamically during runtime, which means that a different set
of steps needs to be taken.

On Linux
~~~~~~~~

First, patch libcurl-impersonate and change its SONAME:

.. code-block:: bash

    patchelf --set-soname libcurl.so.4 /path/to/libcurl-impersonate.so

Then replace at runtime with:

.. code-block:: bash

    LD_PRELOAD=/path/to/libcurl-impersonate.so CURL_IMPERSONATE=chrome101 php -r 'print_r(curl_version());'

If successful you should see:

.. code-block:: bash

    [ssl_version] => BoringSSL


On macOS
~~~~~~~~

First rename ``libcurl-impersonate.dylib`` to ``libcurl.4.dylib`` and place it in a
directory such as ``/usr/local/lib``. Then run PHP with the ``DYLD_LIBRARY_PATH``
environment variable pointing to that directory, for example:

.. code-block:: bash

    DYLD_LIBRARY_PATH=/usr/local/lib php -r 'print_r(curl_version());'

If successful you should see:

.. code-block:: bash

    [ssl_version] => BoringSSL
