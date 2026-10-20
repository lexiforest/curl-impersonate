Impersonation & Fingerprints
============================

The following browser profiles are currently available as preset. We also offer an
extended list as an API on `impersonate.pro <https://impersonate.pro>`_. See :doc:`pro`.

.. csv-table::
   :header: "Browser", "Version", "OS", "Target name", "Wrapper script", "H3 fingerprints"

   "Chrome", "99", "Windows 10", "``chrome99``", "``curl_chrome99``", ""
   "Chrome", "100", "Windows 10", "``chrome100``", "``curl_chrome100``", ""
   "Chrome", "101", "Windows 10", "``chrome101``", "``curl_chrome101``", ""
   "Chrome", "104", "Windows 10", "``chrome104``", "``curl_chrome104``", ""
   "Chrome", "107", "Windows 10", "``chrome107``", "``curl_chrome107``", ""
   "Chrome", "110", "Windows 10", "``chrome110``", "``curl_chrome110``", ""
   "Chrome", "116", "Windows 10", "``chrome116``", "``curl_chrome116``", ""
   "Chrome", "119", "macOS Sonoma", "``chrome119``", "``curl_chrome119``", ""
   "Chrome", "120", "macOS Sonoma", "``chrome120``", "``curl_chrome120``", ""
   "Chrome", "123", "macOS Sonoma", "``chrome123``", "``curl_chrome123``", ""
   "Chrome", "124", "macOS Sonoma", "``chrome124``", "``curl_chrome124``", ""
   "Chrome", "131", "macOS Sonoma", "``chrome131``", "``curl_chrome131``", ""
   "Chrome", "133", "macOS Sequoia", "``chrome133a``", "``curl_chrome133a``", ""
   "Chrome", "136", "macOS Sequoia", "``chrome136``", "``curl_chrome136``", ""
   "Chrome", "142", "macOS Tahoe", "``chrome142``", "``curl_chrome142``", ""
   "Chrome", "145", "macOS Tahoe", "``chrome145``", "``curl_chrome145``", "Yes"
   "Chrome", "146", "macOS Tahoe", "``chrome146``", "``curl_chrome146``", "Yes"
   "Chrome", "150", "macOS Tahoe", "``chrome150``", "``curl_chrome150``", "Yes"
   "Chrome", "151", "Windows 10", "``chrome151``", "``curl_chrome151``", "Yes"
   "Chrome", "151", "macOS 26.0", "``chrome151_macos``", "``curl_chrome151_macos``", "Yes"
   "Chrome", "152", "Windows 10", "``chrome152``", "``curl_chrome152``", "Yes"
   "Chrome", "152", "macOS 26.0", "``chrome152_macos``", "``curl_chrome152_macos``", "Yes"
   "Chrome", "99", "Android 12", "``chrome99_android``", "``curl_chrome99_android``", ""
   "Chrome", "131", "Android 14", "``chrome131_android``", "``curl_chrome131_android``", ""
   "Edge", "99", "Windows 10", "``edge99``", "``curl_edge99``", ""
   "Edge", "101", "Windows 10", "``edge101``", "``curl_edge101``", ""
   "Safari", "15.3", "macOS Big Sur", "``safari153``", "``curl_safari153``", ""
   "Safari", "15.5", "macOS Monterey", "``safari155``", "``curl_safari155``", ""
   "Safari", "17.0", "macOS Sonoma", "``safari170``", "``curl_safari170``", ""
   "Safari", "17.2", "iOS 17.2", "``safari172_ios``", "``curl_safari172_ios``", ""
   "Safari", "18.0", "macOS Sequoia", "``safari180``", "``curl_safari180``", ""
   "Safari", "18.0", "iOS 18.0", "``safari180_ios``", "``curl_safari180_ios``", ""
   "Safari", "18.4", "macOS Sequoia", "``safari184``", "``curl_safari184``", ""
   "Safari", "18.4", "iOS 18.4", "``safari184_ios``", "``curl_safari184_ios``", ""
   "Safari", "26.0", "macOS Tahoe", "``safari260``", "``curl_safari260``", ""
   "Safari", "26.0", "iOS 26.0", "``safari260_ios``", "``curl_safari260_ios``", ""
   "Safari", "26.0.1", "macOS Tahoe", "``safari2601``", "``curl_safari2601``", ""
   "Safari", "27.0", "macOS 27.0", "``safari270``", "``curl_safari270``", "Yes"
   "Safari", "27.0", "iOS 27.0", "``safari270_ios``", "``curl_safari270_ios``", "Yes"
   "Firefox", "133.0", "macOS Sonoma", "``firefox133``", "``curl_firefox133``", ""
   "Firefox", "135.0", "macOS Sonoma", "``firefox135``", "``curl_firefox135``", ""
   "Firefox", "144.0", "macOS Tahoe", "``firefox144``", "``curl_firefox144``", ""
   "Firefox", "147.0", "macOS Tahoe", "``firefox147``", "``curl_firefox147``", "Yes"
   "Firefox", "153.0", "Windows 10", "``firefox153``", "``curl_firefox153``", ""
   "Firefox", "154.0", "Windows 10", "``firefox154``", "``curl_firefox154``", ""
   "Firefox", "155.0", "Windows 10", "``firefox155``", "``curl_firefox155``", ""
   "Tor", "14.5", "macOS Sonoma", "``tor145``", "``curl_tor145``", ""

Notes:

1. Select the browser version and OS you need. Chrome 151 and 152 have separate
   Windows targets (``chrome151``, ``chrome152``) and macOS targets
   (``chrome151_macos``, ``chrome152_macos``). Headers can differ between profiles
   and between HTTP/2 and HTTP/3.
2. The original Safari fingerprints in the upstream fork are not correct. See
   `Issue #215 <https://github.com/lwthiker/curl-impersonate/issues/215>`_.
3. The version postfix ``-a`` in names such as ``chrome133a`` means the profile is an
   alternative version observed in A/B testing rather than an officially rolled update.
4. The H3 column marks profiles with dedicated HTTP/3 fingerprints. The new
   Firefox 153, 154, and 155 profiles do not include dedicated HTTP/3 fingerprints.
   Enabling HTTP/3 in the binary does not make every profile match a browser's
   HTTP/3 fingerprint.

Selecting HTTP/3
----------------

Use ``--http3`` with a profile marked for H3 support:

.. code-block:: sh

   curl_chrome152 --http3 https://www.example.com
   curl_safari270_ios --http3-only https://www.example.com

``--http3`` allows fallback to HTTP/2 or HTTP/1.1. ``--http3-only`` requires
HTTP/3. When a profile supplies separate HTTP/3 default headers, they are used
after HTTP/3 is negotiated; fallback requests use the regular default headers.
Application headers supplied with ``-H`` or ``CURLOPT_HTTPHEADER`` still override
the defaults.

Version 2.3.0 fixes an issue where these separate HTTP/3 defaults were ignored.
This affected ``chrome152``, ``chrome152_macos``, and ``safari270_ios``, whose
HTTP/3 headers differ from their regular defaults.

To generate or update profiles from JSON, see :doc:`dev`.
