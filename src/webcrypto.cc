// Copyright 2026 The BoringSSL Authors
// SPDX-License-Identifier: Apache-2.0
#define BSSL_WEBCRYPTO_IMPLEMENTATION
#include <curl-impersonate/webcrypto.h>

#include <limits.h>
#include <openssl/aes.h>
#include <openssl/bn.h>
#include <openssl/bytestring.h>
#include <openssl/cipher.h>
#include <openssl/digest.h>
#include <openssl/ec.h>
#include <openssl/ec_key.h>
#include <openssl/ecdh.h>
#include <openssl/ecdsa.h>
#include <openssl/evp.h>
#include <openssl/hkdf.h>
#include <openssl/hmac.h>
#include <openssl/mem.h>
#include <openssl/nid.h>
#include <openssl/rsa.h>

namespace {
const EVP_MD *Digest(int hash) {
  switch (hash) {
    case 1:
      return EVP_sha1();
    case 256:
      return EVP_sha256();
    case 384:
      return EVP_sha384();
    case 512:
      return EVP_sha512();
    default:
      return nullptr;
  }
}
int Curve(int curve) {
  switch (curve) {
    case 256:
      return NID_X9_62_prime256v1;
    case 384:
      return NID_secp384r1;
    case 521:
      return NID_secp521r1;
    default:
      return NID_undef;
  }
}
EVP_PKEY *Key(const BSSL_WEBCRYPTO_KEY *key) {
  return reinterpret_cast<EVP_PKEY *>(const_cast<BSSL_WEBCRYPTO_KEY *>(key));
}
BSSL_WEBCRYPTO_KEY *Release(bssl::UniquePtr<EVP_PKEY> key) {
  return reinterpret_cast<BSSL_WEBCRYPTO_KEY *>(key.release());
}
// Temporary output is cleansed even on failure, including unauthenticated
// plaintext produced before an AES-GCM tag check.
class Output {
 public:
  explicit Output(size_t size)
      : data_(static_cast<uint8_t *>(OPENSSL_malloc(size ? size : 1))),
        size_(size) {}
  Output(const Output &) = delete;
  Output &operator=(const Output &) = delete;
  ~Output() {
    if (data_) {
      OPENSSL_cleanse(data_, size_);
      OPENSSL_free(data_);
    }
  }
  uint8_t *data() { return data_; }
  int Finish(BSSL_WEBCRYPTO_BUFFER *out, size_t size) {
    if (!data_ || size > size_) {
      return 0;
    }
    out->data = data_;
    out->len = size;
    data_ = nullptr;
    return 1;
  }

 private:
  uint8_t *data_;
  size_t size_;
};
int Copy(const uint8_t *data, size_t size, BSSL_WEBCRYPTO_BUFFER *out) {
  auto *copy = static_cast<uint8_t *>(size ? OPENSSL_memdup(data, size)
                                           : OPENSSL_malloc(1));
  if (!copy) {
    return 0;
  }
  out->data = copy;
  out->len = size;
  return 1;
}
int Number(const BIGNUM *bn, size_t width, BSSL_WEBCRYPTO_BUFFER *out) {
  if (!bn) {
    return 0;
  }
  if (!width) {
    width = BN_num_bytes(bn);
  }
  Output result(width);
  return result.data() && BN_bn2bin_padded(result.data(), width, bn) &&
         result.Finish(out, width);
}
bssl::UniquePtr<BIGNUM> BN(BSSL_WEBCRYPTO_SLICE bytes) {
  if (!bytes.len) {
    return nullptr;
  }
  return bssl::UniquePtr<BIGNUM>(BN_bin2bn(bytes.data, bytes.len, nullptr));
}
bool CheckKey(EVP_PKEY *key, bool private_key) {
  if (EVP_PKEY_id(key) == EVP_PKEY_RSA) {
    RSA *rsa = EVP_PKEY_get0_RSA(key);
    return rsa && (!private_key || RSA_check_key(rsa));
  }
  if (EVP_PKEY_id(key) == EVP_PKEY_EC) {
    return EC_KEY_check_key(EVP_PKEY_get0_EC_KEY(key));
  }
  return false;
}
bool SignatureInit(EVP_MD_CTX *ctx, const BSSL_WEBCRYPTO_KEY *key, int scheme,
                   int hash, int salt_len, bool sign) {
  const EVP_MD *md = Digest(hash);
  if (!md || (scheme == 3 ? EVP_PKEY_id(Key(key)) != EVP_PKEY_EC
                          : EVP_PKEY_id(Key(key)) != EVP_PKEY_RSA)) {
    return false;
  }
  EVP_PKEY_CTX *pctx;
  if (!(sign ? EVP_DigestSignInit(ctx, &pctx, md, nullptr, Key(key))
             : EVP_DigestVerifyInit(ctx, &pctx, md, nullptr, Key(key)))) {
    return false;
  }
  if (scheme == 2) {
    return salt_len >= 0 &&
           EVP_PKEY_CTX_set_rsa_padding(pctx, RSA_PKCS1_PSS_PADDING) &&
           EVP_PKEY_CTX_set_rsa_pss_saltlen(pctx, salt_len) &&
           EVP_PKEY_CTX_set_rsa_mgf1_md(pctx, md);
  }
  return scheme == 1 || scheme == 3;
}
}  // namespace

void bssl_webcrypto_buffer_free(BSSL_WEBCRYPTO_BUFFER buffer) {
  if (buffer.data) {
    OPENSSL_cleanse(buffer.data, buffer.len);
    OPENSSL_free(buffer.data);
  }
}
void bssl_webcrypto_key_free(BSSL_WEBCRYPTO_KEY *key) {
  EVP_PKEY_free(Key(key));
}
int bssl_webcrypto_digest(int hash, BSSL_WEBCRYPTO_SLICE data,
                          BSSL_WEBCRYPTO_BUFFER *out) {
  const EVP_MD *md = Digest(hash);
  uint8_t bytes[EVP_MAX_MD_SIZE];
  unsigned size;
  return md && EVP_Digest(data.data, data.len, bytes, &size, md, nullptr) &&
         Copy(bytes, size, out);
}
int bssl_webcrypto_hmac(int hash, BSSL_WEBCRYPTO_SLICE key,
                        BSSL_WEBCRYPTO_SLICE data, BSSL_WEBCRYPTO_BUFFER *out) {
  const EVP_MD *md = Digest(hash);
  uint8_t bytes[EVP_MAX_MD_SIZE];
  unsigned size;
  return md && HMAC(md, key.data, key.len, data.data, data.len, bytes, &size) &&
         Copy(bytes, size, out);
}
int bssl_webcrypto_equal(BSSL_WEBCRYPTO_SLICE a, BSSL_WEBCRYPTO_SLICE b) {
  return a.len == b.len &&
         (!a.len || CRYPTO_memcmp(a.data, b.data, a.len) == 0);
}
int bssl_webcrypto_derive(int algorithm, int hash, BSSL_WEBCRYPTO_SLICE key,
                          BSSL_WEBCRYPTO_SLICE salt, BSSL_WEBCRYPTO_SLICE info,
                          uint32_t iterations, uint8_t *out, size_t out_len) {
  const EVP_MD *md = Digest(hash);
  if (!md) {
    return 0;
  }
  if (algorithm == 1) {
    return HKDF(out, out_len, md, key.data, key.len, salt.data, salt.len,
                info.data, info.len);
  }
  if (algorithm == 2 && iterations) {
    return PKCS5_PBKDF2_HMAC(reinterpret_cast<const char *>(key.data), key.len,
                             salt.data, salt.len, iterations, md, out_len, out);
  }
  return 0;
}
int bssl_webcrypto_cipher(int algorithm, int encrypt, BSSL_WEBCRYPTO_SLICE key,
                          BSSL_WEBCRYPTO_SLICE iv, BSSL_WEBCRYPTO_SLICE aad,
                          BSSL_WEBCRYPTO_SLICE data, size_t tag_len,
                          BSSL_WEBCRYPTO_BUFFER *out) {
  if (key.len != 16 && key.len != 24 && key.len != 32) {
    return 0;
  }
  if (data.len > INT_MAX - 32 || iv.len > INT_MAX || aad.len > INT_MAX) {
    return 0;
  }
  if (algorithm == 4) {
    if (data.len % 8 || data.len < (encrypt ? 16u : 24u)) {
      return 0;
    }
    AES_KEY aes;
    int ok = encrypt ? AES_set_encrypt_key(
                           key.data, static_cast<unsigned>(key.len * 8), &aes)
                     : AES_set_decrypt_key(
                           key.data, static_cast<unsigned>(key.len * 8), &aes);
    Output result(data.len + 8);
    if (ok || !result.data()) {
      OPENSSL_cleanse(&aes, sizeof(aes));
      return 0;
    }
    int size =
        encrypt
            ? AES_wrap_key(&aes, nullptr, result.data(), data.data, data.len)
            : AES_unwrap_key(&aes, nullptr, result.data(), data.data, data.len);
    OPENSSL_cleanse(&aes, sizeof(aes));
    return size >= 0 && result.Finish(out, static_cast<size_t>(size));
  }
  const EVP_CIPHER *cipher = nullptr;
  if (algorithm == 1) {
    cipher = key.len == 16   ? EVP_aes_128_gcm()
             : key.len == 24 ? EVP_aes_192_gcm()
                             : EVP_aes_256_gcm();
    if (!iv.len ||
        !(tag_len == 4 || tag_len == 8 || (tag_len >= 12 && tag_len <= 16))) {
      return 0;
    }
    if (!encrypt && data.len < tag_len) {
      return 0;
    }
  } else if (algorithm == 2) {
    cipher = key.len == 16   ? EVP_aes_128_cbc()
             : key.len == 24 ? EVP_aes_192_cbc()
                             : EVP_aes_256_cbc();
  } else if (algorithm == 3) {
    cipher = key.len == 16   ? EVP_aes_128_ctr()
             : key.len == 24 ? EVP_aes_192_ctr()
                             : EVP_aes_256_ctr();
  } else {
    return 0;
  }
  if (algorithm != 1 && iv.len != 16) {
    return 0;
  }
  bssl::UniquePtr<EVP_CIPHER_CTX> ctx(EVP_CIPHER_CTX_new());
  Output result(data.len + 32);
  if (!ctx || !result.data() ||
      !EVP_CipherInit_ex(ctx.get(), cipher, nullptr, nullptr, nullptr,
                         encrypt)) {
    return 0;
  }
  if (algorithm == 1 &&
      !EVP_CIPHER_CTX_ctrl(ctx.get(), EVP_CTRL_GCM_SET_IVLEN,
                           static_cast<int>(iv.len), nullptr)) {
    return 0;
  }
  if (!EVP_CipherInit_ex(ctx.get(), nullptr, nullptr, key.data, iv.data,
                         encrypt)) {
    return 0;
  }
  int count = 0, tail = 0;
  size_t input_len = data.len;
  if (algorithm == 1) {
    if (aad.len && !EVP_CipherUpdate(ctx.get(), nullptr, &count, aad.data,
                                     static_cast<int>(aad.len))) {
      return 0;
    }
    if (!encrypt) {
      input_len -= tag_len;
      if (!EVP_CIPHER_CTX_ctrl(ctx.get(), EVP_CTRL_GCM_SET_TAG,
                               static_cast<int>(tag_len),
                               const_cast<uint8_t *>(data.data + input_len))) {
        return 0;
      }
    }
  }
  if (!EVP_CipherUpdate(ctx.get(), result.data(), &count, data.data,
                        static_cast<int>(input_len)) ||
      !EVP_CipherFinal_ex(ctx.get(), result.data() + count, &tail)) {
    return 0;
  }
  size_t size = static_cast<size_t>(count + tail);
  if (algorithm == 1 && encrypt) {
    if (!EVP_CIPHER_CTX_ctrl(ctx.get(), EVP_CTRL_GCM_GET_TAG,
                             static_cast<int>(tag_len), result.data() + size)) {
      return 0;
    }
    size += tag_len;
  }
  return result.Finish(out, size);
}

BSSL_WEBCRYPTO_KEY *bssl_webcrypto_key_generate(int kind, int curve,
                                                unsigned bits,
                                                BSSL_WEBCRYPTO_SLICE exponent) {
  bssl::UniquePtr<EVP_PKEY> key(EVP_PKEY_new());
  if (!key) {
    return nullptr;
  }
  if (kind == 1) {
    bssl::UniquePtr<RSA> rsa(RSA_new());
    auto e = BN(exponent);
    if (bits > INT_MAX || !rsa || !e ||
        !RSA_generate_key_ex(rsa.get(), bits, e.get(), nullptr) ||
        !EVP_PKEY_set1_RSA(key.get(), rsa.get())) {
      return nullptr;
    }
  } else if (kind == 2 && Curve(curve) != NID_undef) {
    bssl::UniquePtr<EC_KEY> ec(EC_KEY_new_by_curve_name(Curve(curve)));
    if (!ec || !EC_KEY_generate_key(ec.get()) ||
        !EVP_PKEY_set1_EC_KEY(key.get(), ec.get())) {
      return nullptr;
    }
  } else {
    return nullptr;
  }
  return Release(std::move(key));
}
BSSL_WEBCRYPTO_KEY *bssl_webcrypto_key_parse(int private_key,
                                             BSSL_WEBCRYPTO_SLICE der) {
  CBS cbs;
  CBS_init(&cbs, der.data, der.len);
  bssl::UniquePtr<EVP_PKEY> key(private_key ? EVP_parse_private_key(&cbs)
                                            : EVP_parse_public_key(&cbs));
  if (!key || CBS_len(&cbs) || !CheckKey(key.get(), private_key)) {
    return nullptr;
  }
  return Release(std::move(key));
}
BSSL_WEBCRYPTO_KEY *bssl_webcrypto_key_rsa(
    const BSSL_WEBCRYPTO_SLICE parts[8]) {
  bssl::UniquePtr<RSA> rsa(RSA_new());
  bssl::UniquePtr<EVP_PKEY> key(EVP_PKEY_new());
  bssl::UniquePtr<BIGNUM> values[8];
  const size_t count = parts[2].len ? 8 : 2;
  for (size_t i = 0; i < count; i++) {
    values[i] = BN(parts[i]);
    if (!values[i]) {
      return nullptr;
    }
  }
  if (!rsa || !key ||
      !RSA_set0_key(rsa.get(), values[0].get(), values[1].get(),
                    values[2].get())) {
    return nullptr;
  }
  for (size_t i = 0; i < 3; i++) {
    values[i].release();
  }
  if (count == 8) {
    if (!RSA_set0_factors(rsa.get(), values[3].get(), values[4].get())) {
      return nullptr;
    }
    values[3].release();
    values[4].release();
    if (!RSA_set0_crt_params(rsa.get(), values[5].get(), values[6].get(),
                             values[7].get())) {
      return nullptr;
    }
    for (size_t i = 5; i < 8; i++) {
      values[i].release();
    }
    if (!RSA_check_key(rsa.get())) {
      return nullptr;
    }
  }
  if (!EVP_PKEY_set1_RSA(key.get(), rsa.get())) {
    return nullptr;
  }
  return Release(std::move(key));
}
BSSL_WEBCRYPTO_KEY *bssl_webcrypto_key_ec(int curve, BSSL_WEBCRYPTO_SLICE x,
                                          BSSL_WEBCRYPTO_SLICE y,
                                          BSSL_WEBCRYPTO_SLICE d) {
  if (Curve(curve) == NID_undef) {
    return nullptr;
  }
  bssl::UniquePtr<EC_KEY> ec(EC_KEY_new_by_curve_name(Curve(curve)));
  bssl::UniquePtr<EVP_PKEY> key(EVP_PKEY_new());
  auto bx = BN(x), by = BN(y), bd = BN(d);
  if (!ec || !key || !bx || !by ||
      !EC_KEY_set_public_key_affine_coordinates(ec.get(), bx.get(), by.get()) ||
      (d.len && (!bd || !EC_KEY_set_private_key(ec.get(), bd.get()))) ||
      !EC_KEY_check_key(ec.get()) ||
      !EVP_PKEY_set1_EC_KEY(key.get(), ec.get())) {
    return nullptr;
  }
  return Release(std::move(key));
}
int bssl_webcrypto_key_kind(const BSSL_WEBCRYPTO_KEY *key) {
  int id = EVP_PKEY_id(Key(key));
  return id == EVP_PKEY_RSA ? 1 : id == EVP_PKEY_EC ? 2 : 0;
}
int bssl_webcrypto_key_curve(const BSSL_WEBCRYPTO_KEY *key) {
  EC_KEY *ec = EVP_PKEY_get0_EC_KEY(Key(key));
  if (!ec) {
    return 0;
  }
  switch (EC_GROUP_get_curve_name(EC_KEY_get0_group(ec))) {
    case NID_X9_62_prime256v1:
      return 256;
    case NID_secp384r1:
      return 384;
    case NID_secp521r1:
      return 521;
    default:
      return 0;
  }
}
unsigned bssl_webcrypto_key_bits(const BSSL_WEBCRYPTO_KEY *key) {
  return EVP_PKEY_bits(Key(key));
}
int bssl_webcrypto_key_export(const BSSL_WEBCRYPTO_KEY *key, int format,
                              BSSL_WEBCRYPTO_BUFFER *out) {
  if (format == 1 || format == 2) {
    bssl::ScopedCBB cbb;
    if (!CBB_init(cbb.get(), 256)) {
      return 0;
    }
    if (!(format == 1 ? EVP_marshal_public_key(cbb.get(), Key(key))
                      : EVP_marshal_private_key(cbb.get(), Key(key)))) {
      return 0;
    }
    return CBB_finish(cbb.get(), &out->data, &out->len);
  }
  if (format >= 10 && format <= 17) {
    RSA *rsa = EVP_PKEY_get0_RSA(Key(key));
    if (!rsa) {
      return 0;
    }
    const BIGNUM *parts[8];
    RSA_get0_key(rsa, &parts[0], &parts[1], &parts[2]);
    RSA_get0_factors(rsa, &parts[3], &parts[4]);
    RSA_get0_crt_params(rsa, &parts[5], &parts[6], &parts[7]);
    return Number(parts[format - 10], 0, out);
  }
  EC_KEY *ec = EVP_PKEY_get0_EC_KEY(Key(key));
  if (!ec) {
    return 0;
  }
  const EC_GROUP *group = EC_KEY_get0_group(ec);
  const EC_POINT *point = EC_KEY_get0_public_key(ec);
  size_t width = (EC_GROUP_get_degree(group) + 7) / 8;
  if (format == 3) {
    Output result(1 + 2 * width);
    return result.data() &&
           EC_POINT_point2oct(group, point, POINT_CONVERSION_UNCOMPRESSED,
                              result.data(), 1 + 2 * width, nullptr) &&
           result.Finish(out, 1 + 2 * width);
  }
  if (format == 22) {
    return Number(EC_KEY_get0_private_key(ec), width, out);
  }
  if (format == 20 || format == 21) {
    bssl::UniquePtr<BIGNUM> x(BN_new()), y(BN_new());
    return x && y &&
           EC_POINT_get_affine_coordinates_GFp(group, point, x.get(), y.get(),
                                               nullptr) &&
           Number(format == 20 ? x.get() : y.get(), width, out);
  }
  return 0;
}
int bssl_webcrypto_sign(const BSSL_WEBCRYPTO_KEY *key, int scheme, int hash,
                        int salt_len, BSSL_WEBCRYPTO_SLICE data,
                        BSSL_WEBCRYPTO_BUFFER *out) {
  bssl::UniquePtr<EVP_MD_CTX> ctx(EVP_MD_CTX_new());
  if (!ctx || !SignatureInit(ctx.get(), key, scheme, hash, salt_len, true)) {
    return 0;
  }
  size_t size = 0;
  if (!EVP_DigestSign(ctx.get(), nullptr, &size, data.data, data.len)) {
    return 0;
  }
  Output result(size);
  if (!result.data() ||
      !EVP_DigestSign(ctx.get(), result.data(), &size, data.data, data.len)) {
    return 0;
  }
  if (scheme != 3) {
    return result.Finish(out, size);
  }
  bssl::UniquePtr<ECDSA_SIG> sig(ECDSA_SIG_from_bytes(result.data(), size));
  size_t width = (EVP_PKEY_bits(Key(key)) + 7) / 8;
  Output raw(2 * width);
  return sig && raw.data() && BN_bn2bin_padded(raw.data(), width, sig->r) &&
         BN_bn2bin_padded(raw.data() + width, width, sig->s) &&
         raw.Finish(out, 2 * width);
}
int bssl_webcrypto_verify(const BSSL_WEBCRYPTO_KEY *key, int scheme, int hash,
                          int salt_len, BSSL_WEBCRYPTO_SLICE data,
                          BSSL_WEBCRYPTO_SLICE signature) {
  bssl::UniquePtr<EVP_MD_CTX> ctx(EVP_MD_CTX_new());
  if (!ctx || !SignatureInit(ctx.get(), key, scheme, hash, salt_len, false)) {
    return 0;
  }
  if (scheme != 3) {
    return EVP_DigestVerify(ctx.get(), signature.data, signature.len, data.data,
                            data.len) == 1;
  }
  size_t width = (EVP_PKEY_bits(Key(key)) + 7) / 8;
  if (signature.len != 2 * width) {
    return 0;
  }
  bssl::UniquePtr<ECDSA_SIG> sig(ECDSA_SIG_new());
  if (!sig || !BN_bin2bn(signature.data, width, sig->r) ||
      !BN_bin2bn(signature.data + width, width, sig->s)) {
    return 0;
  }
  uint8_t *der = nullptr;
  size_t der_len = 0;
  if (!ECDSA_SIG_to_bytes(&der, &der_len, sig.get())) {
    return 0;
  }
  int valid = EVP_DigestVerify(ctx.get(), der, der_len, data.data, data.len);
  OPENSSL_free(der);
  return valid == 1;
}
int bssl_webcrypto_oaep(const BSSL_WEBCRYPTO_KEY *key, int encrypt, int hash,
                        BSSL_WEBCRYPTO_SLICE label, BSSL_WEBCRYPTO_SLICE data,
                        BSSL_WEBCRYPTO_BUFFER *out) {
  const EVP_MD *md = Digest(hash);
  bssl::UniquePtr<EVP_PKEY_CTX> ctx(EVP_PKEY_CTX_new(Key(key), nullptr));
  if (!md || !ctx || EVP_PKEY_id(Key(key)) != EVP_PKEY_RSA ||
      label.len > INT_MAX ||
      !(encrypt ? EVP_PKEY_encrypt_init(ctx.get())
                : EVP_PKEY_decrypt_init(ctx.get())) ||
      !EVP_PKEY_CTX_set_rsa_padding(ctx.get(), RSA_PKCS1_OAEP_PADDING) ||
      !EVP_PKEY_CTX_set_rsa_oaep_md(ctx.get(), md) ||
      !EVP_PKEY_CTX_set_rsa_mgf1_md(ctx.get(), md)) {
    return 0;
  }
  if (label.len) {
    auto *copy = static_cast<uint8_t *>(OPENSSL_memdup(label.data, label.len));
    if (!copy) {
      return 0;
    }
    if (!EVP_PKEY_CTX_set0_rsa_oaep_label(ctx.get(), copy, label.len)) {
      OPENSSL_free(copy);
      return 0;
    }
  }
  size_t size = EVP_PKEY_size(Key(key));
  Output result(size);
  if (!result.data() ||
      !(encrypt ? EVP_PKEY_encrypt(ctx.get(), result.data(), &size, data.data,
                                   data.len)
                : EVP_PKEY_decrypt(ctx.get(), result.data(), &size, data.data,
                                   data.len))) {
    return 0;
  }
  return result.Finish(out, size);
}
int bssl_webcrypto_ecdh(const BSSL_WEBCRYPTO_KEY *key,
                        const BSSL_WEBCRYPTO_KEY *peer,
                        BSSL_WEBCRYPTO_BUFFER *out) {
  bssl::UniquePtr<EVP_PKEY_CTX> ctx(EVP_PKEY_CTX_new(Key(key), nullptr));
  size_t size = 0;
  if (!ctx || EVP_PKEY_id(Key(key)) != EVP_PKEY_EC ||
      EVP_PKEY_id(Key(peer)) != EVP_PKEY_EC ||
      !EVP_PKEY_derive_init(ctx.get()) ||
      !EVP_PKEY_derive_set_peer(ctx.get(), Key(peer)) ||
      !EVP_PKEY_derive(ctx.get(), nullptr, &size)) {
    return 0;
  }
  Output result(size);
  return result.data() && EVP_PKEY_derive(ctx.get(), result.data(), &size) &&
         result.Finish(out, size);
}
