// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright 2005 Google Inc. All Rights Reserved.

#include "snappy.h"
#include "snappy-internal.h"
#include "snappy-sinksource.h"

#include <stdio.h>
#include <algorithm>
#include <string>
#include <vector>

namespace snappy {
namespace internal {

void WorkingMemory(size_t input_size, size_t* table_size) {
  size_t size = 256;
  while (size < kMaxHashTableSize && size < input_size) {
    size <<= 1;
  }
  *table_size = size;
}

static inline uint32 HashBytes(uint32 bytes, int shift) {
  uint32 kMagic = 0x1e35a7bdU;
  return (bytes * kMagic) >> shift;
}

static inline uint32 Hash(const char* p, int shift) {
  return HashBytes(UNALIGNED_LOAD32(p), shift);
}

static inline char* EmitLiteral(char* op,
                                const char* literal,
                                size_t len,
                                bool allow_fast_path) {
  size_t n = len - 1;
  if (n < 60) {
    *op++ = LITERAL | (static_cast<uint8>(n) << 2);
    if (allow_fast_path && len <= 16) {
      UNALIGNED_STORE64(op, UNALIGNED_LOAD64(literal));
      UNALIGNED_STORE64(op + 8, UNALIGNED_LOAD64(literal + 8));
      return op + len;
    }
  } else {
    int count = (n < 256) ? 1 : ((n < 65536) ? 2 : ((n < 16777216) ? 3 : 4));
    *op++ = LITERAL | (static_cast<uint8>(59 + count) << 2);
    for (int i = 0; i < count; i++) {
      *op++ = n & 0xff;
      n >>= 8;
    }
  }
  memcpy(op, literal, len);
  return op + len;
}

static inline char* EmitCopyLessThan64(char* op, size_t offset, size_t len) {
  assert(len <= 64);
  assert(len >= 4);
  assert(offset > 0);
  assert(offset < 65536);

  if ((len < 12) && (offset < 2048)) {
    size_t len_minus_4 = len - 4;
    assert(len_minus_4 < 8);
    *op++ = COPY_1_BYTE_OFFSET | ((len_minus_4) << 2) | ((offset >> 8) << 5);
    *op++ = offset & 0xff;
  } else {
    *op++ = COPY_2_BYTE_OFFSET | ((len - 1) << 2);
    UNALIGNED_STORE16(op, static_cast<uint16>(offset));
    op += 2;
  }
  return op;
}

static inline char* EmitCopy(char* op, size_t offset, size_t len) {
  // Emit 64-byte chunks
  while (len >= 68) {
    op = EmitCopyLessThan64(op, offset, 64);
    len -= 64;
  }
  // Emit residual
  if (len > 64) {
    op = EmitCopyLessThan64(op, offset, 60);
    len -= 60;
  }
  return EmitCopyLessThan64(op, offset, len);
}

static inline size_t FindMatchLength(const char* s1, const char* s2, const char* s2_limit) {
  size_t matched = 0;
  while (s2 <= s2_limit - 8) {
    uint64 diff = UNALIGNED_LOAD64(s2) ^ UNALIGNED_LOAD64(s1 + matched);
    if (diff != 0) {
#if SNAPPY_IS_BIG_ENDIAN
      return matched + (__builtin_clzll(diff) >> 3);
#else
      return matched + (FindLSBSetNonZero64(diff) >> 3);
#endif
    }
    s2 += 8;
    matched += 8;
  }
  while (s2 < s2_limit && (s1[matched] == *s2)) {
    s2++;
    matched++;
  }
  return matched;
}

char* CompressFragment(const char* input,
                       size_t input_size,
                       char* op,
                       uint16* table,
                       const size_t table_size) {
  if (input_size <= 0) return op;

  const int shift = 32 - BitsLog2Floor(static_cast<uint32>(table_size));
  assert((static_cast<size_t>(1) << (32 - shift)) == table_size);
  memset(table, 0, table_size * sizeof(*table));

  const char* ip = input;
  const char* ip_end = input + input_size;
  const char* base_ip = input;
  const char* next_emit = input;

  const size_t kInputMarginBytes = 15;
  if (SNAPPY_PREDICT_TRUE(input_size >= kInputMarginBytes)) {
    const char* ip_limit = input + input_size - kInputMarginBytes;

    for (uint32 next_hash = Hash(++ip, shift);;) {
      assert(next_emit < ip);
      const char* candidate = nullptr;
      size_t skip = 32;

      const char* next_ip = ip;
      do {
        ip = next_ip;
        uint32 hash = next_hash;
        assert(hash == Hash(ip, shift));
        uint32 bytes_between_hash_lookups = skip++ >> 5;
        next_ip = ip + bytes_between_hash_lookups;
        if (SNAPPY_PREDICT_FALSE(next_ip > ip_limit)) {
          goto emit_remainder;
        }
        next_hash = Hash(next_ip, shift);
        candidate = base_ip + table[hash];
        assert(candidate >= base_ip);
        assert(candidate < ip);
        table[hash] = static_cast<uint16>(ip - base_ip);
      } while (SNAPPY_PREDICT_TRUE(UNALIGNED_LOAD32(ip) != UNALIGNED_LOAD32(candidate)));

      // Step over literal bytes
      op = EmitLiteral(op, next_emit, ip - next_emit, true);

      // Match found
      for (;;) {
        const char* base = ip;
        size_t matched = 4 + FindMatchLength(candidate + 4, ip + 4, ip_end);
        ip += matched;
        size_t offset = base - candidate;
        assert(0 == memcmp(base, candidate, matched));
        op = EmitCopy(op, offset, matched);
        next_emit = ip;

        if (SNAPPY_PREDICT_FALSE(ip >= ip_limit)) {
          goto emit_remainder;
        }

        // Insert previous bytes into hash table
        uint32 prev_hash = Hash(ip - 1, shift);
        table[prev_hash] = static_cast<uint16>(ip - 1 - base_ip);
        uint32 cur_hash = Hash(ip, shift);
        candidate = base_ip + table[cur_hash];
        table[cur_hash] = static_cast<uint16>(ip - base_ip);

        if (UNALIGNED_LOAD32(ip) != UNALIGNED_LOAD32(candidate)) {
          next_hash = Hash(ip + 1, shift);
          ++ip;
          break;
        }
      }
    }
  }

emit_remainder:
  if (next_emit < ip_end) {
    op = EmitLiteral(op, next_emit, ip_end - next_emit, false);
  }
  return op;
}

}  // namespace internal

size_t MaxCompressedLength(size_t source_bytes) {
  return 32 + source_bytes + source_bytes / 6;
}

void RawCompress(const char* input,
                 size_t input_length,
                 char* compressed,
                 size_t* compressed_length) {
  uint8* dest = reinterpret_cast<uint8*>(compressed);
  dest = Varint::Encode32(dest, static_cast<uint32>(input_length));
  char* op = reinterpret_cast<char*>(dest);

  size_t table_size;
  internal::WorkingMemory(input_length, &table_size);

  std::vector<uint16> table_vector(table_size);
  uint16* table = table_vector.data();

  // Compress in 64KB blocks
  for (size_t pos = 0; pos < input_length; pos += internal::kBlockSize) {
    size_t fragment_size = std::min(input_length - pos, internal::kBlockSize);
    op = internal::CompressFragment(input + pos, fragment_size, op, table, table_size);
  }

  *compressed_length = op - compressed;
}

size_t Compress(const char* input, size_t input_length, std::string* output) {
  output->resize(MaxCompressedLength(input_length));
  size_t compressed_length;
  RawCompress(input, input_length, &(*output)[0], &compressed_length);
  output->resize(compressed_length);
  return compressed_length;
}

bool GetUncompressedLength(const char* compressed,
                           size_t compressed_length,
                           size_t* result) {
  uint32 v;
  const char* limit = compressed + compressed_length;
  const char* p = Varint::Parse32WithLimit(compressed, limit, &v);
  if (p == nullptr) return false;
  *result = v;
  return true;
}

bool IsValidCompressedBuffer(const char* compressed,
                             size_t compressed_length) {
  size_t uncompressed_len;
  if (!GetUncompressedLength(compressed, compressed_length, &uncompressed_len)) {
    return false;
  }
  std::string scratch;
  scratch.resize(uncompressed_len);
  return RawUncompress(compressed, compressed_length, &scratch[0]);
}

static inline void IncrementalCopy(const char* src, char* op, ssize_t len) {
  assert(len > 0);
  do {
    *op++ = *src++;
  } while (--len > 0);
}

static inline void IncrementalCopyFastPath(const char* src, char* op, ssize_t len) {
  while (op - src < 8) {
    UNALIGNED_STORE64(op, UNALIGNED_LOAD64(src));
    len -= op - src;
    op += op - src;
  }
  while (len > 0) {
    UNALIGNED_STORE64(op, UNALIGNED_LOAD64(src));
    src += 8;
    op += 8;
    len -= 8;
  }
}

bool RawUncompress(const char* compressed,
                   size_t compressed_length,
                   char* uncompressed) {
  uint32 expected_len = 0;
  const char* ip = compressed;
  const char* ip_limit = compressed + compressed_length;
  ip = Varint::Parse32WithLimit(ip, ip_limit, &expected_len);
  if (ip == nullptr) return false;

  char* op = uncompressed;
  char* op_base = uncompressed;
  char* op_limit = uncompressed + expected_len;

  while (ip < ip_limit) {
    uint8 tag = static_cast<uint8>(*ip++);
    uint8 type = tag & 0x03;

    if (type == internal::LITERAL) {
      size_t len = (tag >> 2) + 1;
      if (len > 60) {
        size_t extra_bytes = len - 60;
        if (ip + extra_bytes > ip_limit) return false;
        len = 0;
        for (size_t i = 0; i < extra_bytes; i++) {
          len |= static_cast<size_t>(static_cast<uint8>(*ip++)) << (i * 8);
        }
        len += 1;
      }
      if (len > static_cast<size_t>(ip_limit - ip)) return false;
      if (len > static_cast<size_t>(op_limit - op)) return false;

      // 16-byte fast copy
      if (len <= 16 && (op_limit - op >= 16) && (ip_limit - ip >= 16)) {
        UNALIGNED_STORE64(op, UNALIGNED_LOAD64(ip));
        UNALIGNED_STORE64(op + 8, UNALIGNED_LOAD64(ip + 8));
        op += len;
        ip += len;
      } else {
        memcpy(op, ip, len);
        op += len;
        ip += len;
      }
    } else {
      size_t len = 0;
      size_t offset = 0;

      if (type == internal::COPY_1_BYTE_OFFSET) {
        if (ip >= ip_limit) return false;
        len = ((tag >> 2) & 0x07) + 4;
        offset = ((tag & 0xe0) << 3) | static_cast<uint8>(*ip++);
      } else if (type == internal::COPY_2_BYTE_OFFSET) {
        if (ip + 2 > ip_limit) return false;
        len = (tag >> 2) + 1;
        offset = UNALIGNED_LOAD16(ip);
        ip += 2;
      } else if (type == internal::COPY_4_BYTE_OFFSET) {
        if (ip + 4 > ip_limit) return false;
        len = (tag >> 2) + 1;
        offset = UNALIGNED_LOAD32(ip);
        ip += 4;
      }

      // Safety bounds checks: offset > 0 and must not underflow historical base
      if (offset == 0 || offset > static_cast<size_t>(op - op_base)) return false;
      if (len > static_cast<size_t>(op_limit - op)) return false;

      const char* src = op - offset;
      if (offset >= 16 && (op_limit - op >= static_cast<ssize_t>(len) + 16)) {
        // Fast unaligned wild copy
        for (size_t copied = 0; copied < len; copied += 16) {
          UNALIGNED_STORE64(op + copied, UNALIGNED_LOAD64(src + copied));
          UNALIGNED_STORE64(op + copied + 8, UNALIGNED_LOAD64(src + copied + 8));
        }
        op += len;
      } else {
        IncrementalCopy(src, op, len);
        op += len;
      }
    }
  }

  return (op == op_limit);
}

size_t Compress(Source* reader, Sink* writer) {
  size_t available = reader->Available();
  std::vector<char> uncompressed_buf(available);
  size_t peek_len;
  const char* peek_data = reader->Peek(&peek_len);
  if (peek_len >= available) {
    std::string comp;
    Compress(peek_data, available, &comp);
    writer->Append(comp.data(), comp.size());
    reader->Skip(available);
    return comp.size();
  }
  return 0;
}

bool Uncompress(Source* reader, Sink* writer) {
  size_t available = reader->Available();
  size_t peek_len;
  const char* peek_data = reader->Peek(&peek_len);
  if (peek_len < available) return false;

  size_t uncompressed_len;
  if (!GetUncompressedLength(peek_data, available, &uncompressed_len)) return false;

  std::vector<char> uncompressed_buf(uncompressed_len);
  if (!RawUncompress(peek_data, available, uncompressed_buf.data())) return false;

  writer->Append(uncompressed_buf.data(), uncompressed_len);
  reader->Skip(available);
  return true;
}

bool Uncompress(const char* compressed, size_t compressed_length, std::string* output) {
  size_t uncompressed_length;
  if (!GetUncompressedLength(compressed, compressed_length, &uncompressed_length)) {
    return false;
  }
  output->resize(uncompressed_length);
  return RawUncompress(compressed, compressed_length, &(*output)[0]);
}

}  // namespace snappy
