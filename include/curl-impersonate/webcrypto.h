// Copyright 2026 The BoringSSL Authors
// SPDX-License-Identifier: Apache-2.0
#ifndef CURL_IMPERSONATE_WEBCRYPTO_H
#define CURL_IMPERSONATE_WEBCRYPTO_H

#include <stddef.h>
#include <stdint.h>

// This interface exposes the crypto primitives needed by a WebCrypto host from
// an embedding library (curl-impersonate). It does not implement WebCrypto key
// usages, extractability, algorithm normalization, or realm ownership.
// Build this translation unit into the embedding shared library, against the
// same pinned BoringSSL as its TLS implementation. No BoringSSL structs cross
// the boundary. This interface must be rebuilt with its consumers.
#if defined(BSSL_WEBCRYPTO_STATIC)
#define BSSL_WEBCRYPTO_EXPORT
#elif defined(_WIN32)
#if defined(BSSL_WEBCRYPTO_IMPLEMENTATION)
#define BSSL_WEBCRYPTO_EXPORT __declspec(dllexport)
#else
#define BSSL_WEBCRYPTO_EXPORT __declspec(dllimport)
#endif
#else
#define BSSL_WEBCRYPTO_EXPORT __attribute__((visibility("default")))
#endif

#if defined(__cplusplus)
extern "C" {
#endif

typedef struct bssl_webcrypto_key_st BSSL_WEBCRYPTO_KEY;
typedef struct {
  const uint8_t *data;
  size_t len;
} BSSL_WEBCRYPTO_SLICE;
typedef struct {
  uint8_t *data;
  size_t len;
} BSSL_WEBCRYPTO_BUFFER;

// Inputs are borrowed for the duration of a call. Empty slices may have NULL
// data. Outputs must initially be {NULL, 0}; successful calls allocate them and
// the caller must release them with bssl_webcrypto_buffer_free. Functions
// return 1 on success and 0 on failure unless documented otherwise. Failed
// operations never return partial plaintext. Key constructors return NULL on
// failure. Hash identifiers are 1=SHA-1, 256=SHA-256, 384=SHA-384, 512=SHA-512.
BSSL_WEBCRYPTO_EXPORT void bssl_webcrypto_buffer_free(
    BSSL_WEBCRYPTO_BUFFER buffer);
BSSL_WEBCRYPTO_EXPORT void bssl_webcrypto_key_free(BSSL_WEBCRYPTO_KEY *key);
BSSL_WEBCRYPTO_EXPORT int bssl_webcrypto_digest(int hash,
                                                BSSL_WEBCRYPTO_SLICE data,
                                                BSSL_WEBCRYPTO_BUFFER *out);
BSSL_WEBCRYPTO_EXPORT int bssl_webcrypto_hmac(int hash,
                                              BSSL_WEBCRYPTO_SLICE key,
                                              BSSL_WEBCRYPTO_SLICE data,
                                              BSSL_WEBCRYPTO_BUFFER *out);
// Returns 1 if the two byte strings are equal. Comparison of equal-length
// strings is constant time; lengths are public.
BSSL_WEBCRYPTO_EXPORT int bssl_webcrypto_equal(BSSL_WEBCRYPTO_SLICE a,
                                               BSSL_WEBCRYPTO_SLICE b);
// Derivation identifiers: 1=HKDF, 2=PBKDF2. HKDF ignores iterations; PBKDF2
// ignores info. The caller supplies an output buffer of exactly out_len bytes.
BSSL_WEBCRYPTO_EXPORT int bssl_webcrypto_derive(int algorithm, int hash,
                                                BSSL_WEBCRYPTO_SLICE key,
                                                BSSL_WEBCRYPTO_SLICE salt,
                                                BSSL_WEBCRYPTO_SLICE info,
                                                uint32_t iterations,
                                                uint8_t *out, size_t out_len);
// Cipher identifiers: 1=AES-GCM, 2=AES-CBC (PKCS#7), 3=AES-CTR (128-bit
// counter), 4=AES-KW (RFC 3394). Keys are 16, 24 or 32 bytes. GCM appends or
// consumes tag_len bytes; CBC/CTR require a 16-byte IV. KW ignores IV.
BSSL_WEBCRYPTO_EXPORT int bssl_webcrypto_cipher(
    int cipher, int encrypt, BSSL_WEBCRYPTO_SLICE key, BSSL_WEBCRYPTO_SLICE iv,
    BSSL_WEBCRYPTO_SLICE aad, BSSL_WEBCRYPTO_SLICE data, size_t tag_len,
    BSSL_WEBCRYPTO_BUFFER *out);
// Key kinds: 1=RSA, 2=EC. Curves: 256=P-256, 384=P-384, 521=P-521.
BSSL_WEBCRYPTO_EXPORT BSSL_WEBCRYPTO_KEY *bssl_webcrypto_key_generate(
    int kind, int curve, unsigned bits, BSSL_WEBCRYPTO_SLICE exponent);
// private_key selects PKCS#8 PrivateKeyInfo (1) or SPKI (0). Trailing bytes
// are rejected. Parsed private keys are checked for internal consistency.
BSSL_WEBCRYPTO_EXPORT BSSL_WEBCRYPTO_KEY *bssl_webcrypto_key_parse(
    int private_key, BSSL_WEBCRYPTO_SLICE der);
// RSA components are unsigned big-endian n,e,d,p,q,dp,dq,qi. A public key has
// empty components after e. A private key must supply all eight components.
BSSL_WEBCRYPTO_EXPORT BSSL_WEBCRYPTO_KEY *bssl_webcrypto_key_rsa(
    const BSSL_WEBCRYPTO_SLICE components[8]);
// EC coordinates and optional private scalar are unsigned big-endian. The
// public point and private/public consistency are checked.
BSSL_WEBCRYPTO_EXPORT BSSL_WEBCRYPTO_KEY *bssl_webcrypto_key_ec(
    int curve, BSSL_WEBCRYPTO_SLICE x, BSSL_WEBCRYPTO_SLICE y,
    BSSL_WEBCRYPTO_SLICE d);
BSSL_WEBCRYPTO_EXPORT int bssl_webcrypto_key_kind(
    const BSSL_WEBCRYPTO_KEY *key);
BSSL_WEBCRYPTO_EXPORT int bssl_webcrypto_key_curve(
    const BSSL_WEBCRYPTO_KEY *key);
BSSL_WEBCRYPTO_EXPORT unsigned bssl_webcrypto_key_bits(
    const BSSL_WEBCRYPTO_KEY *key);
// Formats: 1=SPKI, 2=PKCS#8, 3=uncompressed EC point; 10..17=RSA components
// in the order above, 20..22=EC x,y,d (padded to the curve coordinate width).
BSSL_WEBCRYPTO_EXPORT int bssl_webcrypto_key_export(
    const BSSL_WEBCRYPTO_KEY *key, int format, BSSL_WEBCRYPTO_BUFFER *out);
// Signature schemes: 1=RSASSA-PKCS1-v1_5, 2=RSA-PSS, 3=ECDSA. PSS uses the
// selected hash for both the message and MGF1, and exactly salt_len bytes.
// ECDSA signatures use fixed-width r || s, as required by WebCrypto.
BSSL_WEBCRYPTO_EXPORT int bssl_webcrypto_sign(const BSSL_WEBCRYPTO_KEY *key,
                                              int scheme, int hash,
                                              int salt_len,
                                              BSSL_WEBCRYPTO_SLICE data,
                                              BSSL_WEBCRYPTO_BUFFER *out);
// Returns 1 for a valid signature, 0 for an invalid signature or failed check.
BSSL_WEBCRYPTO_EXPORT int bssl_webcrypto_verify(const BSSL_WEBCRYPTO_KEY *key,
                                                int scheme, int hash,
                                                int salt_len,
                                                BSSL_WEBCRYPTO_SLICE data,
                                                BSSL_WEBCRYPTO_SLICE signature);
BSSL_WEBCRYPTO_EXPORT int bssl_webcrypto_oaep(const BSSL_WEBCRYPTO_KEY *key,
                                              int encrypt, int hash,
                                              BSSL_WEBCRYPTO_SLICE label,
                                              BSSL_WEBCRYPTO_SLICE data,
                                              BSSL_WEBCRYPTO_BUFFER *out);
BSSL_WEBCRYPTO_EXPORT int bssl_webcrypto_ecdh(const BSSL_WEBCRYPTO_KEY *key,
                                              const BSSL_WEBCRYPTO_KEY *peer,
                                              BSSL_WEBCRYPTO_BUFFER *out);

#if defined(__cplusplus)
}  // extern "C"
#endif
#endif  // CURL_IMPERSONATE_WEBCRYPTO_H
