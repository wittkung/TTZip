# TTZip Architecture & Systems Overview

## 1. High-Level System Architecture

TTZip is designed from the ground up to achieve maximum throughput, zero process-overhead latency, and uncompromising safety on macOS 14+ and Apple Silicon processors.

```
┌────────────────────────────────────────────────────────┐
│             TTZipApp (SwiftUI + AppKit)                │
│    Glassmorphic UI, NSOutlineView, QuickLook Preview   │
└──────────────────────────┬─────────────────────────────┘
                           │ Swift 6 Complete Concurrency
┌──────────────────────────▼─────────────────────────────┐
│                 TTZipCore Engine Layer                 │
│  - Pipeline Dispatchers & Strategy Coordinators        │
│  - ArchiveOperationAbstraction (Bridge Pattern)        │
│  - Password Vault v4 (PBKDF2 + AES-256-GCM)            │
│  - Directory Scanners & Flyweight Cache Pools          │
└──────────────────────────┬─────────────────────────────┘
                           │ Safe CUnsafeBufferAdapter
┌──────────────────────────▼─────────────────────────────┐
│            CTTZipBridge (C11 Static Bindings)          │
│  - Native Tar / Zip / 7Z / Zstd / LZMA2 Decoders       │
│  - In-Process libdeflate / libarchive / liblz4         │
│  - ARM NEON SIMD & PMULL CLMUL Acceleration (48 GB/s)  │
└──────────────────────────┬─────────────────────────────┘
                           │ Static Linking (.a)
┌──────────────────────────▼─────────────────────────────┐
│                 Vendor Static Libraries                │
│  libarchive.a, liblzma.a, liblz4.a, libdeflate.a, ... │
└────────────────────────────────────────────────────────┘
```

---

## 2. Core Architectural Invariants

### 2.1 100% In-Process Execution (Zero CLI Spawning)
Traditional macOS archive tools often spawn external CLI processes (such as `tar`, `7z`, or `unrar`) via `Process()` / `posix_spawn`. This approach suffers from:
1. Significant kernel process creation overhead (~10-30 ms per execution).
2. Complex IPC and standard stream parsing bottlenecks.
3. Security vulnerabilities from shell injection and uncontrolled file descriptors.

**TTZip binds 100% statically and in-process**. Every decompression or compression stream flows through tightly optimized memory buffers directly inside the application space.

---

### 2.2 Apple Silicon SIMD & PMULL Acceleration
TTZip leverages dedicated hardware vector instructions on ARM64:
- **PMULL (`vmull_p64`) CRC Pipeline**: Uses 4-way unrolled Galois Field polynomial multiplication to fold 64 bytes per iteration concurrently across four 128-bit vector registers, delivering over **48 GB/s throughput**.
- **ARM NEON AES Cryptography**: Eliminates table-lookup cache timing vulnerabilities by executing AES rounds entirely in vector execution ports.
- **SWAR & Hybrid Match Finders**: Scans 64-bit words in parallel to detect byte matches across DEFLATE and LZMA2 sliding windows.

---

### 2.3 Strict Memory & Alignment Safety
- **Zero Raw Type-Punning**: Buffer tails are processed via byte-wise endianness-aware helpers (`read16le`, `read32le`) or byte-element vector loaders (`vld1q_u8`), guaranteeing 100% alignment safety under `-mstrict-align` and UndefinedBehaviorSanitizer (UBSan).
- **Zero Dynamic Allocation in Hot Loops**: Hot loops utilize pre-allocated thread-local page pools to completely eliminate kernel zero-fill page faults during high-throughput compression streams.
