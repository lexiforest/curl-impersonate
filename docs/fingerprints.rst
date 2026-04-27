Advanced Topics
***************

This section is reserved for lower-level usage notes and edge cases that do not fit in
the quick start guide.

For now, see :doc:`quick_start` for runtime usage and :doc:`building` for build
instructions.

Built-in Browser Profiles
-------------------------

| Browser | Version | Build | OS | Target name | Wrapper script |
| --- | --- | --- | --- | --- | --- |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 99 | 99.0.4844.51 | Windows 10 | `chrome99` | [curl_chrome99](bin/curl_chrome99) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 100 | 100.0.4896.75 | Windows 10 | `chrome100` | [curl_chrome100](bin/curl_chrome100) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 101 | 101.0.4951.67 | Windows 10 | `chrome101` | [curl_chrome101](bin/curl_chrome101) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 104 | 104.0.5112.81 | Windows 10 | `chrome104` | [curl_chrome104](bin/curl_chrome104) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 107 | 107.0.5304.107 | Windows 10 | `chrome107` | [curl_chrome107](bin/curl_chrome107) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 110 | 110.0.5481.177 | Windows 10 | `chrome110` | [curl_chrome110](bin/curl_chrome110) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 116 | 116.0.5845.180 | Windows 10 | `chrome116` | [curl_chrome116](bin/curl_chrome116) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 119 | 119.0.6045.199 | macOS Sonoma | `chrome119` | [curl_chrome119](bin/curl_chrome119) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 120 | 120.0.6099.109 | macOS Sonoma | `chrome120` | [curl_chrome120](bin/curl_chrome120) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 123 | 123.0.6312.124 | macOS Sonoma | `chrome123` | [curl_chrome123](bin/curl_chrome123) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 124 | 124.0.6367.60 | macOS Sonoma | `chrome124` | [curl_chrome124](bin/curl_chrome124) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 131 | 131.0.6778.86 | macOS Sonoma | `chrome131` | [curl_chrome131](bin/curl_chrome131) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 133 | 133.0.6943.55 | macOS Sequoia | `chrome133a` | [curl_chrome133a](bin/curl_chrome133a) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 136 | 136.0.7103.93 | macOS Sequoia | `chrome136` | [curl_chrome136](bin/curl_chrome136) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 99 | 99.0.4844.73 | Android 12 | `chrome99_android` | [curl_chrome99_android](bin/curl_chrome99_android) |
| ![Chrome](https://raw.githubusercontent.com/alrra/browser-logos/main/src/chrome/chrome_24x24.png "Chrome") | 131 | 131.0.6778.81 | Android 14 | `chrome131_android` | [curl_chrome131_android](bin/curl_chrome131_android) |
| ![Edge](https://raw.githubusercontent.com/alrra/browser-logos/main/src/edge/edge_24x24.png "Edge") | 99 | 99.0.1150.30 | Windows 10 | `edge99` | [curl_edge99](bin/curl_edge99) |
| ![Edge](https://raw.githubusercontent.com/alrra/browser-logos/main/src/edge/edge_24x24.png "Edge") | 101 | 101.0.1210.47 | Windows 10 | `edge101` | [curl_edge101](bin/curl_edge101) |
| ![Safari](https://github.com/alrra/browser-logos/blob/main/src/safari/safari_24x24.png "Safari") | 15.3 | 16612.4.9.1.8 | MacOS Big Sur | `safari153` | [curl_safari153](bin/curl_safari153) |
| ![Safari](https://github.com/alrra/browser-logos/blob/main/src/safari/safari_24x24.png "Safari") | 15.5 | 17613.2.7.1.8 | MacOS Monterey | `safari155` | [curl_safari155](bin/curl_safari155) |
| ![Safari](https://github.com/alrra/browser-logos/blob/main/src/safari/safari_24x24.png "Safari") | 17.0 | unclear | MacOS Sonoma | `safari170` | [curl_safari170](bin/curl_safari170) |
| ![Safari](https://github.com/alrra/browser-logos/blob/main/src/safari/safari_24x24.png "Safari") | 17.2 | unclear | iOS 17.2 | `safari172_ios` | [curl_safari172_ios](bin/curl_safari172_ios) |
| ![Safari](https://github.com/alrra/browser-logos/blob/main/src/safari/safari_24x24.png "Safari") | 18.0 | unclear | MacOS Sequoia | `safari180` | [curl_safari180](bin/curl_safari180) |
| ![Safari](https://github.com/alrra/browser-logos/blob/main/src/safari/safari_24x24.png "Safari") | 18.0 | unclear | iOS 18.0 | `safari180_ios` | [curl_safari184_ios](bin/curl_safari180_ios) |
| ![Safari](https://github.com/alrra/browser-logos/blob/main/src/safari/safari_24x24.png "Safari") | 18.4 | unclear | MacOS Sequoia | `safari184` | [curl_safari184](bin/curl_safari184) |
| ![Safari](https://github.com/alrra/browser-logos/blob/main/src/safari/safari_24x24.png "Safari") | 18.4 | unclear | iOS 18.4 | `safari184_ios` | [curl_safari180_ios](bin/curl_safari184_ios) |
| ![Safari](https://github.com/alrra/browser-logos/blob/main/src/safari/safari_24x24.png "Safari") | 26.0 | unclear | MacOS Tahoe | `safari260` | [curl_safari260](bin/curl_safari260) |
| ![Safari](https://github.com/alrra/browser-logos/blob/main/src/safari/safari_24x24.png "Safari") | 26.0 | unclear | iOS 26.0 | `safari260_ios` | [curl_safari260_ios](bin/curl_safari260_ios) |
| ![Firefox](https://github.com/alrra/browser-logos/blob/main/src/firefox/firefox_24x24.png "Firefox") | 133.0 | 133.0.3 | macOS Sonoma | `firefox133` | [curl_firefox133](bin/curl_firefox133) |
| ![Firefox](https://github.com/alrra/browser-logos/blob/main/src/firefox/firefox_24x24.png "Firefox") | 135.0 | 135.0.1 | macOS Sonoma | `firefox135` | [curl_firefox135](bin/curl_firefox135) |
| ![Tor](https://github.com/alrra/browser-logos/blob/main/src/tor/tor_24x24.png "Tor") | 14.5 | 14.5 | macOS Sonoma | `tor145` | [curl_tor145](bin/curl_tor145) |

