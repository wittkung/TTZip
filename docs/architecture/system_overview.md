# TTZip Pro - Software Architecture & Engineering Standards

## 1. System Overview

TTZip Pro is an enterprise-grade, high-performance macOS archive management software built using Swift 6, SwiftUI, AppKit, and low-level C bridge bindings (`CTTZipBridge` & native in-process C archive engines).

```
┌─────────────────────────────────────────────────────────────────┐
│ Layer 3: Presentation & CLI Layer                               │
│   - TTZipApp: NavigationSplitView · @MainActor · NSOutlineView  │
│   - TTZipCLI: ttzip-cli Benchmark Runner & Pipeline Validator   │
└────────────────────────────────┬────────────────────────────────┘
                                 │ Direct Framework Import
┌────────────────────────────────▼────────────────────────────────┐
│ Layer 2: Swift 6 Core Engine Layer                              │
│   - TTZipCore: Streaming Pipeline · 28 Design Patterns ·        │
│     PasswordVault · Sendable Parallel Dispatch · Security       │
└────────────────────────────────┬────────────────────────────────┘
                                 │ module.modulemap Pure C ABI
┌────────────────────────────────▼────────────────────────────────┐
│ Layer 1: C Bridge & Hardware SIMD Acceleration Layer            │
│   - CTTZipBridge: Apple Silicon NEON / AES Micro-Kernels ·      │
│     CPU Capability Dispatch · Micro-Buffering Zero-Copy FastPath│
└────────────────────────────────┬────────────────────────────────┘
                                 │ Static Link / Upstream Isolation
┌────────────────────────────────▼────────────────────────────────┐
│ Layer 0: Pristine Upstream & Vendor Static Libraries            │
│   - Vendor/libarchive-upstream/ (Pristine git worktree / master)│
│   - Vendor/lib/*.a & Vendor/include/ (liblzma, libzstd, libb2)  │
└─────────────────────────────────────────────────────────────────┘
```


---

## 2. Domain Architecture & Responsibilities

### 2.1 TTZipCore (Domain & Core Logic)
- **`Models/`**: Immutable data structures representing archive entries, hierarchical trees, and compression options.
- **`Engines/`**:
  - `ArchiveReader`: Inspects archives via `-slt` key-value parsing to prevent table-alignment regressions.
  - `ArchiveExtractor`: Supports both full streaming extraction and targeted single-item extraction (`7zz e`).
  - `ArchiveWriter`: Multi-core parallel compression engine tuned dynamically per Apple Silicon topology.
  - `NativeParallelEncryptedSplitEngine`: Hardware AES-accelerated encrypted split volume engine.
- **`Security/`**:
  - `PasswordVaultManager`: Manages credentials in macOS Keychain with zero plain-text disk exposure.
  - `SecurityScanner`: Zip-slip path traversal sanitization and dangerous extension auditing.
- **`Utilities/`**:
  - `AppleSiliconTuner`: Detects P-cores/E-cores and configures optimal thread pools.
  - `CharsetDetector`: Auto-detects legacy archive filename encodings (GBK, SHIFT-JIS, UTF-8).

### 2.2 TTZipApp (Presentation Layer)
- **MVVM Architecture**: Views bind strictly to `@MainActor` `AppViewState`.
- **`NativeArchiveOutlineView`**: AppKit `NSOutlineView` bridged via `NSViewRepresentable` to deliver 100% native macOS Finder list-view interactions:
  - `outlineViewItemWillExpand`: Sets `duration = 0.0` for **0ms instant expansion**.
  - `outlineViewItemWillCollapse`: Sets `duration = 0.18` for **smooth native collapse animation**.
- **Resource Management**: Active Task cancellation (`previewTask?.cancel()`) and automatic temporary directory cleanup (`currentTempDir`) on selection change and view disappearance.

### 2.3 CTTZipBridge & Assembly Infrastructure System (AIS)
- **`asm/`**: Low-level Assembly micro-kernels (`.S`) with `arm64inc.S` macro abstraction for DWARF CFI stack unwinding and AAPCS64 ABI compliance.
- **`dispatch/`**: `ttzip_cpu_features` hardware detection and `g_ttzip_dispatch` zero-overhead virtual dispatch table.
- **`harness/`**: Bit-exact differential testing, `mmap` page fault safety guard, and CPB cycle-accurate benchmarking harness.
- **Detailed Specification**: See [`docs/ASSEMBLY_INFRASTRUCTURE_ARCHITECTURE.md`](file:///Users/kevintung/Documents/dev/TTZip/docs/ASSEMBLY_INFRASTRUCTURE_ARCHITECTURE.md) for full design standards and 8 low-level architecture patterns.

### 2.4 Platform & In-Memory Microbenchmarking (TurboBench & lzbench Alignment)
- **`Platform/` (`PlatformMonotonicTimer`)**: 
  - Cross-platform hardware monotonic clock with sub-50ns resolution (macOS `mach_absolute_time` with static timebase caching & 128-bit overflow safety, Windows `QueryPerformanceCounter`, Linux `clock_gettime(CLOCK_MONOTONIC_RAW)`).
- **`Benchmark/` (`InMemoryBenchmarkEngine`)**:
  - 100% in-memory contiguous page-aligned micro-benchmarking engine (zero disk I/O, 16KB page alignment, warmup cache-priming, and 500ms adaptive time-clamping).
  - TurboBench and lzbench metric parity (decimal MB/s, space savings ratio, roundtrip `memcmp` verification, and structured JSON report serialization).
- **TurboBench / lzbench Parity**:
  - Parity and structured JSON report serialization for continuous bilateral differential testing.

---

## 3. Engineering Best Practices

1. **Zero Compiler Warnings (`-warnings-as-errors`)**:
   All modules must compile with zero warnings under strict Swift compiler diagnostics.

2. **Thread Safety & Async/Await**:
   - UI updates execute exclusively on `@MainActor`.
   - Heavy IO/Compression tasks run on `Task.detached(priority: .userInitiated)` to guarantee 60fps UI responsiveness.

3. **Input Method (IME) Compatibility**:
   - Zero `SecureField` usage in popovers or sheets to prevent system-wide macOS TSM Chinese IME blocking.

4. **Security & Sandboxing**:
   - Declared UTI imported type definitions in `Info.plist` for Finder system file associations.

