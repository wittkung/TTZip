# Contributing to TTZip

Thank you for your interest in contributing to **TTZip**! We welcome contributions from systems programmers, performance engineers, and macOS developers passionate about high-performance archiving, SIMD compression acceleration, and native software craftsmanship on Apple Silicon and Intel hardware.

---

## 1. Code of Conduct & Philosophy

- **Extreme Engineering Rigor**: TTZip is built on 100% in-process C static library bindings with zero external CLI subprocess spawning. Every line on hot paths must adhere to zero-heap allocation in tight loops and lock-free concurrency.
- **Architectural Symmetry & Design Patterns**: We value clean, decoupled abstractions using established design patterns (Bridge, Strategy, Factory, Template Method, and Flyweight) in orchestration layers, while strictly isolating data planes and hot loops from pattern overhead.
- **Zero Unnecessary Divergence**: When integrating or porting from upstream reference implementations (such as `libarchive`, `libdeflate`, `zstd`, or `LZMA SDK`), code, comments, and conventions must closely mirror upstream references to minimize cognitive overhead for reviewers.
- **Community Standards & Humility**: We adhere strictly to the [Contributor Covenant v2.1](CODE_OF_CONDUCT.md). We communicate with clarity, empirical data, and technical precision.

---

## 2. Development & Toolchain Requirements

- **Operating System**: macOS Sonoma 14.0+ or macOS Sequoia 15.0+ (Apple Silicon M1/M2/M3/M4/M5 recommended, Intel x86_64 supported).
- **Language**: Swift 6.0 (`swift-tools-version: 6.0`) with Strict Concurrency Checking (`-strict-concurrency=complete`).
- **C/C++ Standard**: C11 / POSIX standard with Clang / LLVM.
- **Dependencies**: 100% in-tree static C libraries under `Vendor/` (`libarchive.a`, `liblzma.a`, `liblz4.a`, `libdeflate.a`, `libzstd.a`, `libb2.a`, `uchardet`). Zero external runtime package dependencies.
- **Optional Tools**: [SwiftLint](https://github.com/realm/SwiftLint) (`brew install swiftlint`) for local style linting.

---

## 3. Git Branching Strategy & Commit Conventions

TTZip enforces a disciplined Git branching model and commit message standard. For the complete specification, refer to [**`docs/governance/BRANCHING_STRATEGY.md`**](docs/governance/BRANCHING_STRATEGY.md).

### 3.1 Branching Taxonomy

All branches branch from and merge back to `main` via Pull Requests:

| Prefix | Description & Purpose | Example |
| :--- | :--- | :--- |
| `main` | Protected production branch. 100% green tests, linear history. | `main` |
| `feat/<name>` | New user-facing features, format additions, or UI capabilities. | `feat/snappy-streaming` |
| `perf/<format>-<optimization>` | Algorithmic, SIMD, and parallel throughput optimizations. | `perf/lzma2-swar-matchfinder` |
| `fix/<issue-id>-<slug>` | Bug fixes, memory leak resolutions, or security patches. | `fix/142-cbr-utf8-crash` |
| `upstream/<lib>-<patch>` | Isolated upstream patches (follows the Upstream Triplet Commit rule). | `upstream/libarchive-pmull-crc32` |
| `release/v<version>` | Release stabilization, version bumping, and appcast signing. | `release/v1.4.0` |
| `docs/<name>` | Documentation updates, architecture guides, and benchmark specs. | `docs/branching-strategy` |
| `chore/<name>` | Build configuration, `.gitignore` maintenance, and linter rules. | `chore/swiftlint-rules` |

### 3.2 Conventional Commits v1.0.0

All commit messages must follow the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) format:

```git
type(scope): subject description

[optional body with technical context]

[optional footer: Closes #123]
```

- **Types**: `feat`, `fix`, `perf`, `refactor`, `test`, `docs`, `chore`, `ci`, `build`, `revert`.
- **Allowed Scopes**:
  - *Formats*: `zip`, `7z`, `tar`, `zstd`, `lzma2`, `lz4`, `brotli`, `lzip`, `lrzip`, `wim`, `dmg`, `iso`, `snappy`, `aar`, `cab`, `rar`.
  - *Core & Crypto*: `crypto`, `bridge`, `stream`, `security`, `scanner`.
  - *UI & Application*: `app`, `ui`, `finder`, `preview`.
  - *CLI & Tools*: `cli`, `bench`.
  - *Infrastructure*: `build`, `ci`, `vendor`, `deps`, `governance`.

### 3.3 Upstream Triplet Commit Rule

When submitting improvements to upstream vendor libraries (`Vendor/*`), the branch must be structured into exactly three atomic commits:
1. `infra: <build system & feature detection changes>`
2. `feat: <core vector algorithm / kernel implementation>`
3. `test: <golden oracle verification & differential regression tests>`

---

## 4. Local Building, Testing & Verification Commands

```bash
# 1. Clone the repository
git clone https://github.com/wittkung/TTZip.git
cd TTZip

# 2. Build Debug
swift build

# 3. Build Release (Direct Distribution Channel)
swift build -c release

# 4. Build Release (Mac App Store Sandbox Channel)
swift build -c release -Xswiftc -DMAS_BUILD

# 5. Run full unit test suite in parallel (580+ tests)
swift test --parallel

# 6. Run memory and thread sanitizer checks
swift test --sanitize=address
swift test --sanitize=thread

# 7. Run Core Performance Floor Gate tests
swift test --filter XCTestPerformanceMeasureTests

# 8. Run Frontend Performance Gate tests (UI/AppKit modifications)
swift test --filter FrontendPerformanceGateTests

# 9. Run single-command offline pre-flight verification gate
./scripts/pre_flight_check.sh

# 10. Run full-matrix CLI benchmark
swift run ttzip-cli bench -f zip
swift run ttzip-cli bench -f 7z
```

---

## 5. Hard Performance Floors & Hot-Path Rules

TTZip enforces non-negotiable throughput floors across all archive formats. Any Pull Request that introduces a real throughput regression ($\Delta < -3.0\%$) on core hot paths will be rejected.

### 5.1 Core Performance Floor Matrix

| Benchmark Scenario | Minimum Throughput (Debug) | Minimum Throughput (Release) |
| :--- | :--- | :--- |
| **ZIP Level 1 Compression (10MB)** | $\ge 1,500\text{ MB/s}$ | $\ge 2,000\text{ MB/s}$ |
| **ZIP Single Large File (50MB)** | $\ge 1,700\text{ MB/s}$ | $\ge 2,100\text{ MB/s}$ |
| **ZIP Level 6 Compression (10MB)** | $\ge 1,100\text{ MB/s}$ | $\ge 1,350\text{ MB/s}$ |
| **ZIP Decompression** | $\ge 7,500\text{ MB/s}$ | $\ge 10,000\text{ MB/s}$ |
| **ZIP Store Direct I/O** | $\ge 6,000\text{ MB/s}$ | $\ge 7,500\text{ MB/s}$ |
| **7Z Level 1 Fast Compression (10MB)** | $\ge 3,200\text{ MB/s}$ | $\ge 3,900\text{ MB/s}$ |
| **7Z Ultra Decompression** | $\ge 6,600\text{ MB/s}$ | $\ge 7,200\text{ MB/s}$ |
| **7Z Compression (LZMA2 Level 5)** | $\ge 480\text{ MB/s}$ | $\ge 620\text{ MB/s}$ |
| **TAR.ZST Direct Compression (50MB)** | $\ge 15,000\text{ MB/s}$ | $\ge 22,000\text{ MB/s}$ |
| **LZ4 In-Process Stream (10MB)** | $\ge 6,000\text{ MB/s}$ | $\ge 10,000\text{ MB/s}$ |
| **TAR.XZ Multi-Core Stream (10MB)** | $\ge 1,200\text{ MB/s}$ | $\ge 1,800\text{ MB/s}$ |
| **7Z AES-256 KDF Key Derivation** | $\le 17\text{ ms}$ | $\le 15\text{ ms}$ |

### 5.2 Zero-Cost Abstraction Hot-Path Rules

1. **Zero Intermediate Heap Allocation**: In tight compression/decompression loops, do not allocate dynamic tree/visitor objects or per-file `Data(count:)` buffers. Utilize thread-local scratch buffers, aligned page pools, or stack buffers.
2. **Lock-Free Concurrency**: Strictly avoid `NSLock`, `pthread_mutex`, or `DispatchSemaphore` calls inside `DispatchQueue.concurrentPerform` or GCD parallel closures.
3. **Fast-Path Preservation**: Never route format-specific optimized fast paths (e.g., C parallel ZIP extraction or Apple Silicon SIMD AES) through generic fallback bridges.
4. **Hardware SIMD Acceleration**: Prioritize ARM64 NEON, PMULL, and AES hardware crypto pipelines on Apple Silicon while maintaining clean portable fallbacks for x86_64.
5. **Strict Pointer Safety & Alignment**: Route all raw buffer operations through `CUnsafeBufferAdapter`. Enforce explicit 32-bit clamping on buffer sizes. Avoid unaligned memory access by using byte-level loaders (`vld1q_u8` or explicit bitshifts).
6. **Subsystem Freeze Policy**: Core ZIP engine components (`ZipParallelExtractor.swift`, `ZipParallelWriter.swift`, `ZipCryptoEngine.swift`, `CTTZipBridge_Crypto.c`, `CTTZipExtract.c`) are frozen against arbitrary modifications unless explicitly authorized.

---

## 6. Comprehensive Pull Request Guidelines

### 6.1 Contribution Lifecycle

```
1. Create Branch        2. Implement & Test      3. Pre-Flight Check     4. Open PR
   git checkout -b         Write unit tests         ./scripts/              Fill PR template
   feat/my-feature         Run sanitizers           pre_flight_check.sh     Verify 5 gates
```

1. **Create a Topic Branch**: Branch off `main` using the correct prefix (e.g. `feat/`, `perf/`, `fix/`).
2. **Implement with TDD**: Accompany all code changes with unit tests in `Tests/TTZipTests/`. Ensure 100% test pass rate.
3. **Run Local Pre-Flight Check**: Execute `./scripts/pre_flight_check.sh` locally to verify cleanliness, linting, unit tests, and performance gates.
4. **Complete the PR Template**: Open a Pull Request on GitHub. The template at [`.github/pull_request_template.md`](.github/pull_request_template.md) will be populated automatically.

### 6.2 The Five Mandatory PR Verification Gates

Every Pull Request must satisfy and check off all five verification gates:

- **Gate A · Performance Floor & Zero Regression**: `swift test --filter XCTestPerformanceMeasureTests` passes with 0% regression against historical peak floors (`604d44d`). Include differential benchmark data if core engines are modified.
- **Gate B · Swift 6 Concurrency**: Clean build under `-strict-concurrency=complete` with zero warnings; `@MainActor` isolation on all UI state updates.
- **Gate C · Sanitizers Security Matrix**: Clean runs under AddressSanitizer (`--sanitize=address`) and ThreadSanitizer (`--sanitize=thread`) with zero memory errors or data races.
- **Gate D · C Bridge & Pointer Safety**: Bounds safety verified through `CUnsafeBufferAdapter`; sensitive memory erased with volatile pointers/`memset_s`; frozen files untouched.
- **Gate E · Dual-Channel Compatibility**: Both Direct release (`swift build -c release`) and Mac App Store sandbox (`swift build -c release -Xswiftc -DMAS_BUILD`) compile cleanly.

### 6.3 Review & Merging Policy

- PRs require at least one maintainer approval.
- Maintainers will merge via **Squash and Merge** (single logical change) or **Rebase and Merge** (curated atomic commit series).
- `main` branch maintains a strictly linear history at all times.

---

Thank you for helping keep TTZip the fastest, safest, and most refined native archiving tool on macOS!
