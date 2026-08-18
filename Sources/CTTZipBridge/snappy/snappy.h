// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright 2005 Google Inc. All Rights Reserved.

#ifndef THIRD_PARTY_SNAPPY_SNAPPY_H_
#define THIRD_PARTY_SNAPPY_SNAPPY_H_

#include <stddef.h>
#include <string>
#include "snappy-stubs-public.h"

namespace snappy {
  class Source;
  class Sink;

  size_t MaxCompressedLength(size_t source_bytes);

  void RawCompress(const char* input,
                   size_t input_length,
                   char* compressed,
                   size_t* compressed_length);

  bool RawUncompress(const char* compressed,
                     size_t compressed_length,
                     char* uncompressed);

  bool GetUncompressedLength(const char* compressed,
                             size_t compressed_length,
                             size_t* result);

  bool IsValidCompressedBuffer(const char* compressed,
                               size_t compressed_length);

  size_t Compress(Source* reader, Sink* writer);

  bool Uncompress(Source* reader, Sink* writer);

  size_t Compress(const char* input, size_t input_length, std::string* output);
  bool Uncompress(const char* compressed, size_t compressed_length, std::string* output);

}  // namespace snappy

#endif  // THIRD_PARTY_SNAPPY_SNAPPY_H_
