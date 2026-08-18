// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright 2011 Google Inc. All Rights Reserved.

#include "snappy-sinksource.h"
#include <string.h>

namespace snappy {

Source::~Source() = default;

Sink::~Sink() = default;

char* Sink::GetAppendBuffer(size_t len, char* scratch) {
  (void)len;
  return scratch;
}

char* Sink::GetAppendBufferVariable(size_t min_size, size_t desired_size_hint,
                                    char* scratch, size_t scratch_size,
                                    size_t* allocated_size) {
  (void)min_size;
  (void)desired_size_hint;
  *allocated_size = scratch_size;
  return scratch;
}

void Sink::AppendAndTakeOwnership(char* bytes, size_t n,
                                  void (*deleter)(void*, const char*, size_t),
                                  void* user_data) {
  Append(bytes, n);
  (*deleter)(user_data, bytes, n);
}

ByteArraySource::~ByteArraySource() = default;

size_t ByteArraySource::Available() const {
  return left_;
}

const char* ByteArraySource::Peek(size_t* len) {
  *len = left_;
  return ptr_;
}

void ByteArraySource::Skip(size_t n) {
  left_ -= n;
  ptr_ += n;
}

UncheckedByteArraySink::~UncheckedByteArraySink() = default;

void UncheckedByteArraySink::Append(const char* data, size_t n) {
  if (data != dest_) {
    memcpy(dest_, data, n);
  }
  dest_ += n;
}

char* UncheckedByteArraySink::GetAppendBuffer(size_t len, char* scratch) {
  (void)len;
  (void)scratch;
  return dest_;
}

char* UncheckedByteArraySink::GetAppendBufferVariable(
    size_t min_size, size_t desired_size_hint, char* scratch,
    size_t scratch_size, size_t* allocated_size) {
  (void)min_size;
  (void)scratch;
  (void)scratch_size;
  *allocated_size = desired_size_hint;
  return dest_;
}

void UncheckedByteArraySink::AppendAndTakeOwnership(
    char* bytes, size_t n, void (*deleter)(void*, const char*, size_t),
    void* user_data) {
  Append(bytes, n);
  (*deleter)(user_data, bytes, n);
}

}  // namespace snappy
