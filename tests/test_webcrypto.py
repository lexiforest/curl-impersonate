"""Check the public crypto interface in the installed curl shared library."""
import ctypes
import hashlib
from pathlib import Path
import sys

import pytest


class Slice(ctypes.Structure):
    _fields_ = [('data', ctypes.c_void_p), ('len', ctypes.c_size_t)]


class Buffer(ctypes.Structure):
    _fields_ = [('data', ctypes.c_void_p), ('len', ctypes.c_size_t)]


@pytest.fixture(scope='module')
def library(request):
    prefix = Path(request.config.getoption('--install-dir'))
    filename = ('libcurl-impersonate.dll' if sys.platform == 'win32' else
                'libcurl-impersonate.dylib' if sys.platform == 'darwin' else
                'libcurl-impersonate.so')
    lib = ctypes.CDLL(str(prefix / 'lib' / filename))
    lib.bssl_webcrypto_digest.argtypes = [ctypes.c_int, Slice, ctypes.POINTER(Buffer)]
    lib.bssl_webcrypto_digest.restype = ctypes.c_int
    lib.bssl_webcrypto_buffer_free.argtypes = [Buffer]
    lib.bssl_webcrypto_buffer_free.restype = None
    lib.curl_version.restype = ctypes.c_char_p
    return lib


def test_crypto_and_tls_share_the_curl_library(library):
    assert b'BoringSSL' in library.curl_version()
    for name in ['buffer_free', 'key_free', 'digest', 'hmac', 'equal', 'derive',
                 'cipher', 'key_generate', 'key_parse', 'key_rsa', 'key_ec',
                 'key_kind', 'key_curve', 'key_bits', 'key_export', 'sign',
                 'verify', 'oaep', 'ecdh']:
        assert getattr(library, 'bssl_webcrypto_' + name)
    # Only the deliberate bridge is public; native BoringSSL types/API stay private.
    assert not hasattr(library, 'EVP_Digest')


@pytest.mark.parametrize('algorithm, name', [(1,'sha1'),(256,'sha256'),(384,'sha384'),(512,'sha512')])
def test_digest_through_exported_interface(library, algorithm, name):
    data = ctypes.create_string_buffer(b'abc')
    output = Buffer()
    assert library.bssl_webcrypto_digest(algorithm, Slice(ctypes.addressof(data),3), ctypes.byref(output)) == 1
    try:
        assert ctypes.string_at(output.data,output.len) == hashlib.new(name,b'abc').digest()
    finally:
        library.bssl_webcrypto_buffer_free(output)


def test_unsupported_hash_has_no_output(library):
    output = Buffer()
    assert library.bssl_webcrypto_digest(42, Slice(None,0), ctypes.byref(output)) == 0
    assert not output.data and output.len == 0
