// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright 2011 Google Inc. All Rights Reserved.

#ifndef THIRD_PARTY_SNAPPY_SNAPPY_SINKSOURCE_H_
#define THIRD_PARTY_SNAPPY_SNAPPY_SINKSOURCE_H_

#include <stddef.h>

namespace snappy {

class Source {
 public:
  Source() = default;
  virtual ~Source();
  virtual size_t Available() const = 0;
  virtual const char* Peek(size_t* len) = 0;
  virtual void Skip(size_t n) = 0;

 private:
  Source(const Source&) = delete;
  Source& operator=(const Source&) = delete;
};

class Sink {
 public:
  Sink() = default;
  virtual ~Sink();
  virtual void Append(const char* bytes, size_t n) = 0;
  virtual char* GetAppendBuffer(size_t len, char* scratch);
  virtual char* GetAppendBufferVariable(
      size_t min_size, size_t desired_size_hint, char* scratch,
      size_t scratch_size, size_t* allocated_size);
  virtual void AppendAndTakeOwnership(
      char* bytes, size_t n, void (*deleter)(void*, const char*, size_t),
      void* user_data);

 private:
  Sink(const Sink&) = delete;
  Sink& operator=(const Sink&) = delete;
};

class ByteArraySource : public Source {
 public:
  ByteArraySource(const char* p, size_t n) : ptr_(p), left_(n) {}
  virtual ~ByteArraySource();
  virtual size_t Available() const;
  virtual const char* Peek(size_t* len);
  virtual void Skip(size_t n);

 private:
  const char* ptr_;
  size_t left_;
};

class UncheckedByteArraySink : public Sink {
 public:
  explicit UncheckedByteArraySink(char* dest) : dest_(dest) {}
  virtual ~UncheckedByteArraySink();
  virtual void Append(const char* data, size_t n);
  virtual char* GetAppendBuffer(size_t len, char* scratch);
  virtual char* GetAppendBufferVariable(
      size_t min_size, size_t desired_size_hint, char* scratch,
      size_t scratch_size, size_t* allocated_size);
  virtual void AppendAndTakeOwnership(
      char* bytes, size_t n, void (*deleter)(void*, const char*, size_t),
      void* user_data);
  char* CurrentDestination() const { return dest_; }

 private:
  char* dest_;
};

}  // namespace snappy

#endif  // THIRD_PARTY_SNAPPY_SNAPPY_SINKSOURCE_H_
