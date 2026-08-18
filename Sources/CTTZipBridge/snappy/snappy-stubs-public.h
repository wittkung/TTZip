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

#ifndef THIRD_PARTY_SNAPPY_SNAPPY_STUBS_PUBLIC_H_
#define THIRD_PARTY_SNAPPY_SNAPPY_STUBS_PUBLIC_H_

#include <stdint.h>
#include <stddef.h>

#if defined(__has_include)
#if __has_include(<sys/uio.h>)
#define SNAPPY_HAVE_SYS_UIO_H 1
#include <sys/uio.h>
#endif
#endif

#define SNAPPY_MAJOR 1
#define SNAPPY_MINOR 2
#define SNAPPY_PATCHLEVEL 1
#define SNAPPY_VERSION ((SNAPPY_MAJOR << 16) | (SNAPPY_MINOR << 8) | SNAPPY_PATCHLEVEL)

namespace snappy {

typedef int8_t int8;
typedef uint8_t uint8;
typedef int16_t int16;
typedef uint16_t uint16;
typedef int32_t int32;
typedef uint32_t uint32;
typedef int64_t int64;
typedef uint64_t uint64;

typedef ptrdiff_t intptr_t;
typedef size_t uintptr_t;

}  // namespace snappy

#endif  // THIRD_PARTY_SNAPPY_SNAPPY_STUBS_PUBLIC_H_
