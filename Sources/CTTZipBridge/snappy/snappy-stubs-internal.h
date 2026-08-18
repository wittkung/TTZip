// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright 2011 Google Inc. All Rights Reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//     * Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above
// copyright notice, this list of conditions and the following disclaimer
// in the documentation and/or other materials provided with the
// distribution.
//     * Neither the name of Google Inc. nor the names of its
// contributors may be used to endorse or promote products derived from
// this software without specific prior written permission.

#ifndef THIRD_PARTY_SNAPPY_OPENSOURCE_SNAPPY_STUBS_INTERNAL_H_
#define THIRD_PARTY_SNAPPY_OPENSOURCE_SNAPPY_STUBS_INTERNAL_H_

#include "snappy-stubs-public.h"

#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <algorithm>
#include <string>

#if defined(__GNUC__) || defined(__clang__)
#define SNAPPY_PREDICT_TRUE(x) (__builtin_expect(false || (x), true))
#define SNAPPY_PREDICT_FALSE(x) (__builtin_expect(false || (x), false))
#define SNAPPY_ATTRIBUTE_ALWAYS_INLINE __attribute__((always_inline))
#elif defined(_MSC_VER)
#define SNAPPY_PREDICT_TRUE(x) (x)
#define SNAPPY_PREDICT_FALSE(x) (x)
#define SNAPPY_ATTRIBUTE_ALWAYS_INLINE __forceinline
#else
#define SNAPPY_PREDICT_TRUE(x) (x)
#define SNAPPY_PREDICT_FALSE(x) (x)
#define SNAPPY_ATTRIBUTE_ALWAYS_INLINE
#endif

#ifndef SNAPPY_IS_BIG_ENDIAN
#if defined(__BYTE_ORDER__) && (__BYTE_ORDER__ == __ORDER_BIG_ENDIAN__)
#define SNAPPY_IS_BIG_ENDIAN 1
#elif defined(_BYTE_ORDER) && (_BYTE_ORDER == _BIG_ENDIAN)
#define SNAPPY_IS_BIG_ENDIAN 1
#else
#define SNAPPY_IS_BIG_ENDIAN 0
#endif
#endif

namespace snappy {

static inline int FindLSBSetNonZero(uint32 n) {
#if defined(__GNUC__) || defined(__clang__)
    return __builtin_ctz(n);
#elif defined(_MSC_VER)
    unsigned long where;
    _BitScanForward(&where, n);
    return where;
#else
    int rc = 31;
    for (int i = 4, shift = 1 << 4; i >= 0; --i, shift >>= 1) {
        if ((n << shift) != 0) {
            n <<= shift;
            rc -= shift;
        }
    }
    return rc;
#endif
}

static inline int FindLSBSetNonZero64(uint64 n) {
#if defined(__GNUC__) || defined(__clang__)
    return __builtin_ctzll(n);
#elif defined(_MSC_VER) && defined(_M_X64)
    unsigned long where;
    _BitScanForward64(&where, n);
    return where;
#else
    return FindLSBSetNonZero(static_cast<uint32>(n == 0 ? n >> 32 : n));
#endif
}

static inline int BitsLog2Floor(uint32 n) {
    if (n == 0) return -1;
#if defined(__GNUC__) || defined(__clang__)
    return 31 ^ __builtin_clz(n);
#elif defined(_MSC_VER)
    unsigned long where;
    _BitScanReverse(&where, n);
    return where;
#else
    int log = 0;
    while (n >>= 1) ++log;
    return log;
#endif
}

class Varint {
 public:
  static const int kMax32 = 5;
  static uint8* Encode32(uint8* sptr, uint32 v) {
    static const int B = 128;
    if (v < (1 << 7)) {
      *(sptr++) = v;
    } else if (v < (1 << 14)) {
      *(sptr++) = v | B;
      *(sptr++) = v >> 7;
    } else if (v < (1 << 21)) {
      *(sptr++) = v | B;
      *(sptr++) = (v >> 7) | B;
      *(sptr++) = v >> 14;
    } else if (v < (1 << 28)) {
      *(sptr++) = v | B;
      *(sptr++) = (v >> 7) | B;
      *(sptr++) = (v >> 14) | B;
      *(sptr++) = v >> 21;
    } else {
      *(sptr++) = v | B;
      *(sptr++) = (v >> 7) | B;
      *(sptr++) = (v >> 14) | B;
      *(sptr++) = (v >> 21) | B;
      *(sptr++) = v >> 28;
    }
    return sptr;
  }

  static const char* Parse32WithLimit(const char* p, const char* l, uint32* OUTPUT) {
    const char* orig_p = p;
    uint32 b;
    uint32 result;
    if (p >= l) return nullptr;
    b = *(reinterpret_cast<const uint8*>(p++)); result = b & 0x7f;
    if (!(b & 0x80)) { *OUTPUT = result; return p; }
    if (p >= l) return nullptr;
    b = *(reinterpret_cast<const uint8*>(p++)); result |= (b & 0x7f) <<  7;
    if (!(b & 0x80)) { *OUTPUT = result; return p; }
    if (p >= l) return nullptr;
    b = *(reinterpret_cast<const uint8*>(p++)); result |= (b & 0x7f) << 14;
    if (!(b & 0x80)) { *OUTPUT = result; return p; }
    if (p >= l) return nullptr;
    b = *(reinterpret_cast<const uint8*>(p++)); result |= (b & 0x7f) << 21;
    if (!(b & 0x80)) { *OUTPUT = result; return p; }
    if (p >= l) return nullptr;
    b = *(reinterpret_cast<const uint8*>(p++)); result |= (b & 0x7f) << 28;
    if (!(b & 0x80)) { *OUTPUT = result; return p; }
    return nullptr; // Varint too long or corrupt
  }
};

static inline uint16 UNALIGNED_LOAD16(const void *p) {
  uint16 t;
  memcpy(&t, p, sizeof(t));
  return t;
}

static inline uint32 UNALIGNED_LOAD32(const void *p) {
  uint32 t;
  memcpy(&t, p, sizeof(t));
  return t;
}

static inline uint64 UNALIGNED_LOAD64(const void *p) {
  uint64 t;
  memcpy(&t, p, sizeof(t));
  return t;
}

static inline void UNALIGNED_STORE16(void *p, uint16 v) {
  memcpy(p, &v, sizeof(v));
}

static inline void UNALIGNED_STORE32(void *p, uint32 v) {
  memcpy(p, &v, sizeof(v));
}

static inline void UNALIGNED_STORE64(void *p, uint64 v) {
  memcpy(p, &v, sizeof(v));
}

}  // namespace snappy

#endif  // THIRD_PARTY_SNAPPY_OPENSOURCE_SNAPPY_STUBS_INTERNAL_H_
