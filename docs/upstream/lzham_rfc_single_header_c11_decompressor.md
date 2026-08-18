# RFC Proposal: Standalone Single-Header ANSI C11 Decompressor (lzham_decomp_c.h)

**Target Repository**: `richgel999/lzham_codec`  
**Topic**: RFC Issue Discussion  

---

### Proposal Overview

We would like to propose adding a lightweight, zero-dependency, single-header ANSI C11 decompression library (`lzham_decomp_c.h`) to the LZHAM repository.

---

### Motivation

While LZHAM offers outstanding compression ratios and decompression speeds (competitive with LZMA2/Zstd), downstream C-only projects and system tools (such as minizip, libarchive, OS kernel utilities, and embedded runtimes) face integration friction due to LZHAM's deep C++03 class/template hierarchies and runtime memory management.

---

### Key Architecture Design

1. **Single-Header C11 API**: Exposes clean C structs (`lzham_c_bitstream_reader_t`, `lzham_c_ring_dict_t`, `lzham_c_huffman_lut_t`) with no `libc++` or C++ standard library dependencies.
2. **Zero-Allocation Hot Path**: Memory is provided upfront via caller-managed page buffers or a fixed single Arena allocation, eliminating internal heap lock contention during multithreaded streaming decompression.
3. **Branchless Prefix Decoding**: Direct 11-bit lookup tables (2048 entries, 8 KB L1D cache-friendly) providing single-cycle symbol resolution for codes <= 11 bits.
4. **Power-of-Two Masked Circular Dictionary**: Eliminates boundary branches in circular window updates via `(dst - dist) & mask` and formal overflow-safe bounds checking.

---

### Community Feedback

We have a working reference implementation verified with comprehensive test suites and benchmark comparisons. We would love to hear feedback from @richgel999 and the community on whether an official single-header C decompressor is welcome in upstream LZHAM.
