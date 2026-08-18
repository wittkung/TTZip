<!--
TTZip Pull Request Template
Please review CONTRIBUTING.md before submitting your pull request.
Ensure all verification gates are satisfied locally before opening the PR.
-->

## 1. Summary & Motivation

<!-- Provide a concise description of what this PR accomplishes and why it is needed. (min length 10 characters) -->

### Related Issue
<!-- Reference the related issue using standard GitHub keywords, e.g., Closes #123, Fixes #456, Resolves #789 -->
Closes #

### Type of Change
<!-- Select all that apply: -->
- [ ] `bug_fix`: Non-breaking fix resolving a functional defect or crash
- [ ] `perf_optimization`: Performance enhancement, SIMD vectorization, or algorithmic optimization
- [ ] `feature`: New user-facing capability, format support, or CLI subcommand
- [ ] `refactor`: Structural codebase improvement without behavior change
- [ ] `security_upstream`: Upstream C security vulnerability fix or defensive boundary enhancement

---

## 2. Scope & Affected Subsystems

<!-- Select all subsystems modified in this PR: -->
- [ ] `Sources/CTTZipBridge/`: C11/POSIX low-level bindings, SIMD vector engines, and crypto primitives
- [ ] `Sources/TTZipCore/`: Swift 6 core archive pipeline, format handlers, benchmarks, security scanning
- [ ] `Sources/TTZipApp/`: SwiftUI / AppKit desktop application and UI components
- [ ] `Sources/TTZipCLI/`: Command-line interface toolchain (`ttzip-cli`)
- [ ] `Tests/TTZipTests/`: Unit tests, pattern test suites, and performance benchmark test cases
- [ ] `Vendor/`: Precompiled C static libraries (`Vendor/*.a`) and C headers

---

## 3. Mandatory Verification Gates (Checklist)

> [!IMPORTANT]
> All mandatory gates must be physically verified on macOS 14+ Apple Silicon / Intel hardware before merging. Zero regression tolerance.

### A. Performance Floor & Zero-Regression Gate
- [ ] `performanceFloorPassed`: `swift test --filter XCTestPerformanceMeasureTests` executed with **0% throughput regression** against historical peak floor (`604d44d`).
- [ ] `frontendGatePassed`: `swift test --filter FrontendPerformanceGateTests` passed within latency limits (if `Sources/TTZipApp/` or UI modified; N/A if non-UI).
- [ ] `zeroAllocationHotPath`: Zero heap allocations (`malloc`/`free`/`Data(count:)`) and zero dynamic object tree creations on compression/decompression hot loops.

### B. Swift 6 Concurrency & Toolchain Gate
- [ ] `swiftConcurrencyPassed`: Clean build under Swift 6 strict concurrency (`-strict-concurrency=complete`) with zero data race warnings or errors.
- [ ] `@MainActor` isolation verified for all UI state updates and AppKit view models.
- [ ] Zero locks (`NSLock`, `pthread_mutex`, `DispatchSemaphore`) inside `DispatchQueue.concurrentPerform` or GCD parallel closures.

### C. Sanitizers Security Matrix (ASan & TSan)
- [ ] `addressSanitizerPassed`: `swift test --sanitize=address` executed with zero memory leaks, buffer overruns, or use-after-free diagnostics.
- [ ] `threadSanitizerPassed`: `swift test --sanitize=thread` executed with zero race conditions or concurrent access violations.

### D. C Bridge & Pointer Safety
- [ ] `pointerSafetyVerified`: All C pointer boundaries routed through `CUnsafeBufferAdapter` with explicit bounds and 32-bit clamping.
- [ ] Sensitive memory & cryptographic keys erased via volatile function pointer / `memset_s` (no dead-store elimination).
- [ ] Frozen file policy strictly respected (`ZipParallelExtractor.swift`, `CTTZipBridge_Crypto.c`, etc.) unless `FORCE UNFREEZE ZIP` was explicitly authorized.

### E. Dual-Channel Compatibility
- [ ] `dualChannelCompatibility`: Both Direct release (`swift build -c release`) and Mac App Store sandbox (`swift build -c release -Xswiftc -DMAS_BUILD`) compile cleanly.
- [ ] All Direct-only dependencies (e.g. Sparkle updater) isolated within `#if !MAS_BUILD` conditional blocks.

---

## 4. Benchmark Differential Comparison Table

<!--
Required if Sources/CTTZipBridge/ or Sources/TTZipCore/ are affected.
Fill with real physical benchmark results from `swift test --filter XCTestPerformanceMeasureTests` or `ttzip-cli bench`.
Status: GREEN (gain >= +3.0%), WHITE (flat within ±3.0%), RED (regression > 3.0% - BLOCKS MERGE)
-->

- **Hardware Profile**: Apple Silicon M-Series / Intel Core (e.g., Apple M3 Max 16-core, 64GB RAM, macOS 14.5)
- **Compiler Flags**: `-O3 -whole-module-optimization`

| Scenario | Baseline Peak (`604d44d`) (MB/s) | Observed in This PR (MB/s) | Delta ($\Delta\%$) | Status (`GREEN` / `WHITE` / `RED`) |
| :--- | :---: | :---: | :---: | :---: |
| ZIP Level 1 Compression (10MB) | 8,381.5 | _ | _% | `WHITE` |
| ZIP Decompression | 12,721.9 | _ | _% | `WHITE` |
| 7Z Level 1 Fast Compression (10MB) | 28,926.3 | _ | _% | `WHITE` |
| 7Z Ultra Decompression | 10,683.6 | _ | _% | `WHITE` |
| TAR.ZST Direct Compression (50MB) | 25,773.3 | _ | _% | `WHITE` |
| TAR.XZ Multi-Core Streaming (10MB) | 5,159.6 | _ | _% | `WHITE` |
| LZ4 In-Process Streaming (10MB) | 18,960.7 | _ | _% | `WHITE` |

---

## 5. Exact Verification Commands

<!-- List the exact shell commands executed locally to verify this PR -->

```bash
# 1. Cleanliness & Linter
git status --porcelain
swiftlint --strict

# 2. Parallel Unit Tests & Sanitizers
swift test --parallel
swift test --sanitize=address
swift test --sanitize=thread

# 3. Performance Floor Gates
swift test --filter XCTestPerformanceMeasureTests
swift test --filter FrontendPerformanceGateTests

# 4. Dual-Channel Compilation
swift build -c release
swift build -c release -Xswiftc -DMAS_BUILD
```
