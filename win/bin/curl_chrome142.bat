:: The list of ciphers can be obtained by looking at the Client Hello message in
:: Wireshark, then converting it using this reference
:: https://wiki.mozilla.org/Security/Cipher_Suites
@echo off
"%~dp0curl.exe" --compressed --impersonate "chrome142" %*
