# Contributing to TTZip

Thank you for your interest in contributing to **TTZip**! We welcome contributions from developers, researchers, and systems programmers who are passionate about high-performance archiving and compression engineering on macOS and Apple Silicon.

---

## 1. Code of Conduct & Philosophy

- **Extreme Engineering Rigor**: TTZip is built on 100% in-process C static library bindings with zero external CLI process spawning. Every line in hot paths must respect zero-heap allocation in tight loops.
- **Architectural Respect**: We value strict adherence to established designs and clean, symmetrical abstractions (e.g., Bridge, Strategy, Factory, and Template Method patterns).
- **Zero Unnecessary Divergence**: When integrating or porting from upstream reference implementations (like libarchive, libdeflate, or LZMA SDK), code, comments, and conventions must closely mirror the reference source to minimize cognitive overhead for reviewers.
- **Humility & Collaboration**: We communicate with clarity, technical precision, and deep respect for the broader open-source ecosystem.

---

## 2. Development & Toolchain Requirements

- **macOS**: Sonoma 14.0+ (Apple Silicon M1/M2/M3/M4/M5 recommended, Intel x86_64 supported)
- **Language**: Swift 6.0 (`swift-tools-version: 6.0`) with Strict Concurrency Checking (`-strict-concurrency=complete`)
- **C/C++ Standard**: C11 / POSIX standard with Clang / LLVM
- **Dependencies**: 100% in-tree static C libraries under `Vendor/` (`libarchive.a`, `liblzma.a`, `liblz4.a`, `libdeflate.a`, `libzstd.a`, `libb2.a`, `uchardet`).

---

## 3. Building and Testing

```bash
# Clone the repository
git clone https://github.com/wittkung/TTZip.git
cd TTZip

# Build Debug
swift build

# Build Release (Direct Distribution)
swift build -c release

# Build Release for Mac App Store Sandbox (-DMAS_BUILD)
swift build -c release -Xswiftc -DMAS_BUILD

# Run the complete test suite (520+ unit tests)
swift test

# Run performance gate verification tests
swift test --filter XCTestPerformanceMeasureTests

# Run full matrix CLI benchmark
swift run ttzip-cli bench -f zip
swift run ttzip-cli bench -f 7z
```

---

## 4. Hard Performance Invariants (Performance Gates)

TTZip enforces hard, non-negotiable performance floors across all archive formats. Any Pull Request that introduces a throughput regression ($\Delta < -3.0\%$) on core hot paths will fail CI.

| Benchmark Scenario | Minimum Throughput (Debug) | Minimum Throughput (Release) |
| :--- | :--- | :--- |
| **ZIP Level 1 (10MB)** | >= 1,500 MB/s | >= 2,000 MB/s |
| **ZIP Extraction** | >= 7,500 MB/s | >= 10,000 MB/s |
| **7Z Level 1 (10MB)** | >= 3,200 MB/s | >= 3,900 MB/s |
| **7Z Extraction** | >= 6,600 MB/s | >= 7,200 MB/s |
| **TAR.ZST Direct (50MB)** | >= 15,000 MB/s | >= 22,000 MB/s |
| **LZ4 In-Process Stream** | >= 6,000 MB/s | >= 10,000 MB/s |

### Hot-Path Rules:
1. **Zero Intermediate Heap Allocation**: In tight compression/decompression loops, do not allocate dynamic tree/visitor wrappers or allocate per-file buffers. Use thread-local scratch buffers or page pools.
2. **Apple Silicon Hardware Acceleration**: Always preserve and prefer NEON/PMULL/AES hardware crypto pipelines over generic fallback loops.
3. **No Unsafe Type-Punning**: Use byte-level loaders (`vld1q_u8` or explicit bitshifts `read32le`) to remain 100% compliant with `-mstrict-align` and UndefinedBehaviorSanitizer (UBSan).

---

## 5. Pull Request Guidelines

1. **Focused, Atomic Commits**: Keep commits logical, focused, and bisectable (`git bisect`-friendly).
2. **Test Coverage**: Accompany every bug fix or feature with corresponding unit tests in `Tests/TTZipTests/`.
3. **Upstream Submissions**: If your work contributes improvements to upstream libraries (`Vendor/*`), follow the respective project's `CONTRIBUTING` guide, respect upstream maintainer conventions, and ensure zero gratuitous diffs.
4. **Documentation**: Update relevant Markdown documents in `docs/` and public APIs when altering interfaces or schemas.

Thank you for helping make TTZip the fastest, safest native archiving tool on macOS!
