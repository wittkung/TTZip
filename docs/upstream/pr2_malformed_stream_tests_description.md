### Summary
Add deterministic boundary and malformed stream regression test coverage to `snappy_unittest.cc`.

### Background & Appreciation
> Snappy guarantees that its decompressor will never crash or execute undefined behavior on corrupt or malicious inputs.
> While `CorruptedTest` and `VerifyCorrupted` execute pseudo-random bit flipping across valid streams, this PR supplements the test suite with targeted, deterministic malformed stream test vectors.
> Huge thanks to the Snappy team for the continuous emphasis on memory safety and fuzzing robustness!

### Test Coverage Details
`Snappy.MalformedStreamBoundaryExhaustion` asserts that `GetUncompressedLength()`, `IsValidCompressedBuffer()`, and `Uncompress()` handle corrupted byte sequences safely across 8 specific boundary cases, reinforcing resilience against malformed stream parsing errors and unintended memory exhaustion:

- **`snappy::GetUncompressedLength()`**: Returns `false` on malformed/non-terminating varints (Cases 1, 2) or successfully parses declared length when the varint header is syntactically valid (Cases 3, 4, 5, 6, 7, 8).
- **`snappy::IsValidCompressedBuffer()` & `snappy::Uncompress()`**: Return `false` gracefully without out-of-bounds reads, memory leaks, hangs, or triggering undefined behavior across all cases.

#### Test Cases:
1. **Empty Buffer**: 0-byte input stream.
2. **Non-terminating Varint**: 10 consecutive `0x80` bytes (exceeding standard varint encoding length without a terminating 7-bit byte).
3. **Oversized Varint with Immediate EOF**: Declares 1 GiB (`\x80\x80\x80\x80\x04`), but buffer terminates immediately without payload chunks.
4. **Literal Run Overrun**: Tag specifies 60 literal bytes, but stream ends after 2 bytes.
5. **Illegal LZ77 Copy Offset 0**: Tag encodes a copy offset of 0.
6. **Lookback Offset Exceeding History (Backward OOB Defense)**: Copy offset (100 bytes) exceeds previously emitted history (4 bytes).
7. **Truncated Multi-Byte Literal Header**: Tag specifies 2-byte length, but stream ends before header completion.
8. **Truncated 4-Byte Copy Offset**: 4-byte copy tag followed by only 1 offset byte.

### Verification / How Has This Been Tested

#### 1. Standard GoogleTest Execution
```bash
mkdir build && cd build
cmake .. -DSNAPPY_BUILD_TESTS=ON -DSNAPPY_BUILD_BENCHMARKS=OFF
cmake --build .
./snappy_unittest --gtest_filter=Snappy.MalformedStreamBoundaryExhaustion
# Physical Output:
# [ RUN      ] Snappy.MalformedStreamBoundaryExhaustion
# [       OK ] Snappy.MalformedStreamBoundaryExhaustion (50 ms)
# [  PASSED  ] 1 test.
```

#### 2. Sanitizer Verification (AddressSanitizer + UndefinedBehaviorSanitizer)
```bash
mkdir build_sanitizer && cd build_sanitizer
cmake .. -DCMAKE_CXX_FLAGS="-fsanitize=address,undefined" -DCMAKE_C_FLAGS="-fsanitize=address,undefined" -DSNAPPY_BUILD_TESTS=ON -DSNAPPY_BUILD_BENCHMARKS=OFF
cmake --build .
./snappy_unittest --gtest_filter=Snappy.MalformedStreamBoundaryExhaustion
# Physical Output:
# [ RUN      ] Snappy.MalformedStreamBoundaryExhaustion
# [       OK ] Snappy.MalformedStreamBoundaryExhaustion (64 ms)
# [  PASSED  ] 1 test.
#
# (Zero AddressSanitizer heap/stack OOB violations, zero UBSan undefined pointer/shift errors)
```

---
*Happy to make any adjustments or add further test cases requested by the maintainers!*
