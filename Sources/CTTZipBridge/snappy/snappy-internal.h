// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright 2008 Google Inc. All Rights Reserved.

#ifndef THIRD_PARTY_SNAPPY_OPENSOURCE_SNAPPY_INTERNAL_H_
#define THIRD_PARTY_SNAPPY_OPENSOURCE_SNAPPY_INTERNAL_H_

#include "snappy-stubs-internal.h"

namespace snappy {
namespace internal {

static const int kMaxHashTableBits = 14;
static const size_t kMaxHashTableSize = 1 << kMaxHashTableBits;

static const int LITERAL = 0;
static const int COPY_1_BYTE_OFFSET = 1;
static const int COPY_2_BYTE_OFFSET = 2;
static const int COPY_4_BYTE_OFFSET = 3;

static const int kBlockLog = 16;
static const size_t kBlockSize = 1 << kBlockLog;

void WorkingMemory(size_t input_size, size_t* table_size);

char* CompressFragment(const char* input,
                       size_t input_size,
                       char* op,
                       uint16* table,
                       const size_t table_size);

char* CompressFragmentDoubleHash(const char* input,
                                 size_t input_size,
                                 char* op,
                                 uint16* table,
                                 const size_t table_size);

}  // namespace internal
}  // namespace snappy

#endif  // THIRD_PARTY_SNAPPY_OPENSOURCE_SNAPPY_INTERNAL_H_
