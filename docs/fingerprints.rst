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
   "Firefox", "133.0", "macOS Sonoma", "``firefox133``", "``curl_firefox133``", ""
   "Firefox", "135.0", "macOS Sonoma", "``firefox135``", "``curl_firefox135``", ""
   "Firefox", "144.0", "macOS Tahoe", "``firefox144``", "``curl_firefox144``", ""
   "Firefox", "147.0", "macOS Tahoe", "``firefox147``", "``curl_firefox147``", "Yes"
   "Tor", "14.5", "macOS Sonoma", "``tor145``", "``curl_tor145``", ""

Notes:

1. Chromium-based browsers all share the same fingerprints, except for the
   ``User-Agent`` header and ``sec-ch-ua-platform`` header. They will not be updated
   unless this assumption changes. Use your own headers if you need to impersonate
   Edge, Chrome Android, and similar variants.
2. The original Safari fingerprints in the upstream fork are not correct. See
   `Issue #215 <https://github.com/lwthiker/curl-impersonate/issues/215>`_.
3. The version postfix ``-a`` in names such as ``chrome133a`` means the profile is an
   alternative version observed in A/B testing rather than an officially rolled update.
