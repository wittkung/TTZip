# TTZip Git Branching Strategy & Commit Governance

> **Status**: Active Standard | **Applies to**: `wittkung/TTZip` & Upstream Contributions  
> **Reference**: Conventional Commits v1.0.0, Semantic Versioning 2.0.0

---

## 1. Overview

TTZip is a high-performance, in-process native archiving and compression engine for macOS. To maintain an immaculate, bisectable Git history, prevent regressions, and segregate upstream vendor contributions, this document formalizes our **Branching Taxonomy**, **Branch Protection Rules**, **Conventional Commits Specification**, and **Upstream Triplet Commit Standard**.

```
                           ┌─ feat/snappy-streaming ──────┐
                           ├─ perf/lzma2-swar-matchfinder ─┤
main (protected, linear) ──┼─ fix/142-cbr-utf8-crash ──────┼──> main (v1.4.0)
                           ├─ upstream/libarchive-pmull ───┤
                           └─ release/v1.4.0 ──────────────┘
```

---

## 2. Branching Taxonomy

All development branches branch off latest `main` and merge back to `main` via Pull Request (with the exception of isolated `upstream/*` worktrees). Branch names must strictly adhere to the prefixes defined below:

| Branch Name Pattern | Base Branch | Target Branch | Description & Use Case | Example |
| :--- | :--- | :--- | :--- | :--- |
| `main` | N/A | N/A | **Protected production trunk**. Always releasable, 100% green tests, linear history. | `main` |
| `feat/<name>` | `main` | `main` | New user-facing feature, UI capability, or format support addition. | `feat/snappy-streaming`<br>`feat/tabbed-archive-browser` |
| `perf/<format>-<optimization>` | `main` | `main` | Performance enhancements, SIMD vectorization, memory reduction, zero-copy hot paths. | `perf/lzma2-swar-matchfinder`<br>`perf/zstd-neon-vector` |
| `fix/<issue-id>-<slug>` | `main` | `main` | Bug fixes, crash resolutions, memory safety fixes, or security patches. | `fix/142-cbr-utf8-crash`<br>`fix/89-zip-eocd-truncation` |
| `upstream/<lib>-<patch>` | `main` / upstream | upstream / `Vendor/` | Isolated patches for upstream libraries (`libarchive`, `zstd`, `libdeflate`, `xz`). Follows Triplet Commit rule. | `upstream/libarchive-pmull-crc32`<br>`upstream/zstd-arm64-asm` |
| `release/v<version>` | `main` | `main` | Release candidate stabilization, appcast updates, version bumps, and final validation. | `release/v1.4.0`<br>`release/v2.0.0-rc1` |
| `docs/<name>` | `main` | `main` | Documentation, architecture specs, governance rules, benchmark reports, and manual pages. | `docs/branching-strategy`<br>`docs/benchmark-matrix-update` |
| `chore/<name>` | `main` | `main` | Toolchain updates, build scripts, `.gitignore` maintenance, and SwiftLint configuration. | `chore/swiftlint-rules`<br>`chore/gitignore-hardening` |

---

## 3. Branch Protection Requirements on `main`

The `main` branch represents production-ready code and is protected by the following mandatory requirements:

1. **Direct Pushes Forbidden**: No commits may be pushed directly to `main`. All changes must arrive via Pull Requests.
2. **Mandatory Pull Request & Code Review**: Every PR must receive at least one approving code review from a core maintainer before merging.
3. **Linear Git History**: Merge commits on `main` are disabled. PRs must be merged using **Squash and Merge** (for single-purpose feature/fix branches) or **Rebase and Merge** (for multi-commit atomic series).
4. **Mandatory Local Pre-Flight Verification**: PR authors must physically run `./scripts/pre_flight_check.sh` on macOS 14+ Apple Silicon/Intel hardware and verify:
   - Zero untracked or dirty repository artifacts (`git status --porcelain`).
   - SwiftLint and codebase invariant linters pass with zero warnings (`swiftlint --strict`).
   - Full test suite passes in parallel (`swift test --parallel`).
   - Performance floor gate passes with zero regressions (`swift test --filter XCTestPerformanceMeasureTests`).
5. **CI Status Checks**: When GitHub Actions workflows are manually dispatched (`workflow_dispatch`), all matrix jobs (build, test, sanitizers) must complete with a green status.

---

## 4. Conventional Commits v1.0.0 Specification

Commit messages across all branches must follow the [Conventional Commits v1.0.0](https://www.conventionalcommits.org/en/v1.0.0/) standard:

```
<type>(<scope>): <short description in imperative mood>

[optional body: detailed technical rationale and data]

[optional footer(s): issue references, breaking changes]
```

### 4.1 Allowed Types

| Type | Intent & Usage |
| :--- | :--- |
| `feat` | Introduces a new feature, new archive format capability, or UI addition. |
| `fix` | Patches a bug, crash, memory leak, or incorrect extraction/compression behavior. |
| `perf` | Code change that improves execution speed, memory footprint, or SIMD throughput. |
| `refactor` | Code restructuring that neither fixes a bug nor adds a feature or changes performance. |
| `test` | Adding missing unit tests, fuzzing tests, or golden oracle test fixtures. |
| `docs` | Documentation changes only (`README.md`, `docs/`, `GEMINI.md`, man pages). |
| `chore` | Maintenance tasks, `.gitignore` updates, dependency/submodule updates, build script tweaks. |
| `ci` | Changes to CI workflows, local pre-flight check scripts, or test harnesses. |
| `build` | Changes to `Package.swift`, `CMakeLists.txt`, Xcode project settings, or compiler flags. |
| `revert` | Reverts a previous commit. |

### 4.2 Allowed Subsystem Scopes

Scopes must specify the affected subsystem or format module:

| Category | Allowed Scopes | Description |
| :--- | :--- | :--- |
| **Archive Formats** | `zip`, `7z`, `tar`, `zstd`, `lzma2`, `lz4`, `brotli`, `lzip`, `lrzip`, `wim`, `dmg`, `iso`, `snappy`, `aar`, `cab`, `rar` | Format-specific encoders, decoders, and parsers |
| **Crypto & Core** | `crypto`, `bridge`, `stream`, `security`, `scanner` | AES-256 SIMD crypto, C bridge, stream buffers, security auditing |
| **UI & Application** | `app`, `ui`, `finder`, `preview` | SwiftUI views, AppKit outline views, QuickLook preview, Finder integration |
| **CLI & Tools** | `cli`, `bench` | `ttzip-cli` toolchain, benchmarking runners, command dispatch |
| **Infrastructure** | `build`, `ci`, `vendor`, `deps`, `governance` | Package manifests, static C libraries, vendor headers, governance docs |

### 4.3 Commit Message Examples

**Valid Examples:**
```git
feat(snappy): implement in-process parallel stream compressor
perf(lzma2): optimize SWAR matchfinder throughput on Apple Silicon
fix(cbr): resolve UTF-8 filename decoding buffer overflow in CBR parser
docs(governance): add branching strategy and PR contribution guide
ci(pre-flight): add automated performance floor gate verification
```

**Breaking Change Example:**
```git
feat(bridge)!: replace legacy C archive handle with zero-copy stream descriptor

BREAKING CHANGE: The `CTTZipBridge_OpenArchive` API now requires an explicit 
`CTTZipStreamDescriptor` instead of a raw POSIX file descriptor.
```

---

## 5. Upstream Triplet Commit Rule for `upstream/*` Branches

When developing patches intended for external upstream open-source libraries (e.g. `libarchive`, `zstd`, `libdeflate`, `xz` under `Vendor/`), branches prefixed with `upstream/` **must strictly structure changes into three atomic commits**:

```
Commit 1: infra:   Build system, CMake/Autotools, and feature detection
Commit 2: feat:    Core algorithm, SIMD vectorization, or kernel implementation
Commit 3: test:    Golden oracle verification and differential regression tests
```

### Commit 1: `infra` (Build & Infrastructure)
- Updates `CMakeLists.txt`, `Makefile.am`, or header declarations.
- Adds runtime and compile-time CPU architecture and instruction set detection (e.g., ARM64 PMULL, NEON, AVX2).
- Example: `infra: add ARM64 PMULL feature detection and CMake target`

### Commit 2: `feat` (Core Implementation)
- Implements the pure vector algorithm, SIMD hot path, or optimized C kernel.
- Zero unrelated refactoring or whitespace noise; strict C11/C99 compatibility.
- Example: `feat: implement hardware-accelerated PMULL CRC64 checksum`

### Commit 3: `test` (Verification & Golden Oracles)
- Adds standalone regression tests against project-native golden oracles.
- Includes boundary testing, zero-length input testing, and multi-gigabyte buffer assertions.
- Example: `test: add golden oracle differential tests for PMULL CRC64`

> [!IMPORTANT]
> Every commit in the Triplet must independently compile and pass all tests to maintain `git bisect` capability across upstream history.

---

## 6. Pull Request & Merge Workflow

```
1. Create Branch  ──>  2. Atomic Commits  ──>  3. Pre-Flight Check  ──>  4. Open PR  ──>  5. Squash/Rebase Merge
   feat/xyz            Conventional            ./scripts/               Fill 5 Gates      Linear history on main
                       Commits v1.0.0          pre_flight_check.sh      PR Template
```

1. **Branch Creation**:
   ```bash
   git checkout main
   git pull --ff-only
   git checkout -b feat/my-new-feature
   ```
2. **Rebasing onto Main**:
   Keep feature branches up-to-date with `main` via rebase rather than merge commits:
   ```bash
   git fetch origin
   git rebase origin/main
   ```
3. **Local Pre-Flight Gate**:
   Before opening or requesting review on a PR, execute:
   ```bash
   ./scripts/pre_flight_check.sh
   ```
4. **Submitting the PR**:
   Follow the PR template at [`.github/pull_request_template.md`](file:///Users/kevintung/Documents/dev/TTZip/.github/pull_request_template.md) and check off all 5 mandatory verification gates.
