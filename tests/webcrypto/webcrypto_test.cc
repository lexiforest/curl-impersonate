// Copyright 2026 The BoringSSL Authors
// SPDX-License-Identifier: Apache-2.0
#include <array>
#include <vector>
#include <gtest/gtest.h>
#include <curl-impersonate/webcrypto.h>

namespace {
BSSL_WEBCRYPTO_SLICE Bytes(const std::vector<uint8_t> &v) {
  return {v.data(), v.size()};
}
struct Buffer {
  BSSL_WEBCRYPTO_BUFFER value = {nullptr, 0};
  ~Buffer() { bssl_webcrypto_buffer_free(value); }
  std::vector<uint8_t> bytes() const {
    return {value.data, value.data + value.len};
  }
};
struct Key {
  BSSL_WEBCRYPTO_KEY *value;
  ~Key() { bssl_webcrypto_key_free(value); }
};
TEST(WebCryptoTest, DigestAndAuthenticationFailure) {
  Buffer digest;
  ASSERT_TRUE(bssl_webcrypto_digest(256, {nullptr, 0}, &digest.value));
  EXPECT_EQ(
      digest.bytes(),
      (std::vector<uint8_t>{0xe3, 0xb0, 0xc4, 0x42, 0x98, 0xfc, 0x1c, 0x14,
                            0x9a, 0xfb, 0xf4, 0xc8, 0x99, 0x6f, 0xb9, 0x24,
                            0x27, 0xae, 0x41, 0xe4, 0x64, 0x9b, 0x93, 0x4c,
                            0xa4, 0x95, 0x99, 0x1b, 0x78, 0x52, 0xb8, 0x55}));
  for (size_t size : {16u, 24u, 32u}) {
    std::vector<uint8_t> key(size), iv(12), data{1, 2, 3}, aad{4};
    Buffer encrypted;
    ASSERT_TRUE(bssl_webcrypto_cipher(1, 1, Bytes(key), Bytes(iv), Bytes(aad),
                                      Bytes(data), 16, &encrypted.value));
    auto damaged = encrypted.bytes();
    damaged.back() ^= 1;
    Buffer decrypted;
    EXPECT_FALSE(bssl_webcrypto_cipher(1, 0, Bytes(key), Bytes(iv), Bytes(aad),
                                       Bytes(damaged), 16, &decrypted.value));
    EXPECT_EQ(decrypted.value.data, nullptr);
    EXPECT_EQ(decrypted.value.len, 0u);
  }
}
TEST(WebCryptoTest, ECSerializationAndSignatureWidths) {
  for (int curve : {256, 384, 521}) {
    Key key{bssl_webcrypto_key_generate(2, curve, 0, {nullptr, 0})};
    ASSERT_NE(key.value, nullptr);
    Buffer spki, pkcs8;
    ASSERT_TRUE(bssl_webcrypto_key_export(key.value, 1, &spki.value));
    ASSERT_TRUE(bssl_webcrypto_key_export(key.value, 2, &pkcs8.value));
    Key public_key{
        bssl_webcrypto_key_parse(0, {spki.value.data, spki.value.len})};
    Key private_key{
        bssl_webcrypto_key_parse(1, {pkcs8.value.data, pkcs8.value.len})};
    ASSERT_NE(public_key.value, nullptr);
    ASSERT_NE(private_key.value, nullptr);
    EXPECT_EQ(bssl_webcrypto_key_curve(private_key.value), curve);
    Buffer sig;
    ASSERT_TRUE(bssl_webcrypto_sign(private_key.value, 3, 512, 0, {nullptr, 0},
                                    &sig.value));
    EXPECT_EQ(sig.value.len, 2u * ((curve + 7) / 8));
    EXPECT_TRUE(bssl_webcrypto_verify(public_key.value, 3, 512, 0, {nullptr, 0},
                                      {sig.value.data, sig.value.len}));
    sig.value.data[0] ^= 1;
    EXPECT_FALSE(bssl_webcrypto_verify(public_key.value, 3, 512, 0,
                                       {nullptr, 0},
                                       {sig.value.data, sig.value.len}));
    auto trailing = pkcs8.bytes();
    trailing.push_back(0);
    Key invalid{bssl_webcrypto_key_parse(1, Bytes(trailing))};
    EXPECT_EQ(invalid.value, nullptr);
  }
}
TEST(WebCryptoTest, RSAWrappingAndKeyAgreement) {
  std::vector<uint8_t> exponent{1, 0, 1}, data{1, 2, 3}, label{4, 5};
  Key rsa{bssl_webcrypto_key_generate(1, 0, 2048, Bytes(exponent))};
  ASSERT_NE(rsa.value, nullptr);
  Buffer wrapped, unwrapped;
  ASSERT_TRUE(bssl_webcrypto_oaep(rsa.value, 1, 256, Bytes(label), Bytes(data),
                                  &wrapped.value));
  ASSERT_TRUE(bssl_webcrypto_oaep(rsa.value, 0, 256, Bytes(label),
                                  {wrapped.value.data, wrapped.value.len},
                                  &unwrapped.value));
  EXPECT_EQ(unwrapped.bytes(), data);
  Buffer invalid;
  EXPECT_FALSE(bssl_webcrypto_oaep(rsa.value, 0, 256, {nullptr, 0},
                                   {wrapped.value.data, wrapped.value.len},
                                   &invalid.value));
  EXPECT_EQ(invalid.value.data, nullptr);
  Key a{bssl_webcrypto_key_generate(2, 256, 0, {nullptr, 0})};
  Key b{bssl_webcrypto_key_generate(2, 256, 0, {nullptr, 0})};
  ASSERT_NE(a.value, nullptr);
  ASSERT_NE(b.value, nullptr);
  Buffer x, y;
  ASSERT_TRUE(bssl_webcrypto_ecdh(a.value, b.value, &x.value));
  ASSERT_TRUE(bssl_webcrypto_ecdh(b.value, a.value, &y.value));
  EXPECT_EQ(x.bytes(), y.bytes());
}
}  // namespace
