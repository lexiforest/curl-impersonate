Bindings
========

With Python
-----------

We have an official Python binding
`curl_cffi <https://github.com/lexiforest/curl_cffi>`_, which works on Linux, macOS and
Windows.

With JavaScript
---------------

We have an official Nodejs TypeScript binding

There are a few other community-driven projects.

With PHP
--------

You can use libcurl-impersonate in PHP scripts instead of the original libcurl. Because
PHP loads libcurl dynamically at runtime, the setup steps are slightly different.

On Linux
~~~~~~~~

First, patch libcurl-impersonate and change its SONAME:

.. code-block:: bash

    patchelf --set-soname libcurl.so.4 /path/to/libcurl-impersonate.so

Then load it at runtime with:

.. code-block:: bash

    LD_PRELOAD=/path/to/libcurl-impersonate.so CURL_IMPERSONATE=chrome101 php -r 'print_r(curl_version());'

If everything is set up correctly, you should see:

.. code-block:: bash

    [ssl_version] => BoringSSL


On macOS
~~~~~~~~

First, rename ``libcurl-impersonate.dylib`` to ``libcurl.4.dylib`` and place it in a
directory such as ``/usr/local/lib``. Then run PHP with ``DYLD_LIBRARY_PATH`` pointing
to that directory, for example:

.. code-block:: bash

    DYLD_LIBRARY_PATH=/usr/local/lib php -r 'print_r(curl_version());'

If everything is set up correctly, you should see:

.. code-block:: bash

    [ssl_version] => BoringSSL
