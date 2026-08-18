# Security Policy

TTZip is committed to delivering a secure, reliable, and high-performance native archiving engine for macOS. We take all potential security vulnerabilities seriously and work diligently to investigate and remediate reported issues.

---

## Supported Versions

We actively maintain and provide security updates for the following versions:

| Version | Status | Notes |
| :--- | :--- | :--- |
| **1.x / `main`** | :white_check_mark: Active Support | Current stable release and development trunk; receives security patches |
| **< 1.0** | :x: Unsupported | Pre-release versions; users should upgrade to the latest stable release |

---

## Reporting a Vulnerability

**Please DO NOT report security vulnerabilities via public GitHub Issues, Discussions, or Pull Requests.**

To report a vulnerability responsibly:

1. **GitHub Security Advisory (Preferred)**:
   Submit a private report via [GitHub Security Advisories](https://github.com/wittkung/TTZip/security/advisories/new).
2. **Email (Secondary)**:
   Send an encrypted or direct email to the maintainer at **`witt.w.kung@gmail.com`** with the subject line:
   `[SECURITY] TTZip Vulnerability Report - <Brief Description>`

### Information to Include

To help us triage and resolve the issue efficiently, please include:
- Affected TTZip version(s), commit hash, and operating system build (e.g., macOS Sonoma 14.5, Apple Silicon M-series or Intel x86_64).
- Type of vulnerability (e.g., Path Traversal, Memory Safety, Denial of Service, Cryptographic Flaw).
- Step-by-step instructions or proof-of-concept (PoC) archive file to reproduce the issue.
- Impact assessment and potential attack vectors.

---

## Response Timeline & Remediation Process

| Milestone | Target Window | Description |
| :--- | :--- | :--- |
| **Initial Acknowledgement** | **Within 48 hours** | Maintainer confirms receipt of the vulnerability report. |
| **Triage & Assessment** | **Within 3 business days** | Validate the vulnerability, determine CVSS severity, and identify affected components. |
| **Patch & Verification** | **Within 7 business days** | Develop fix in a private branch, run full regression suite and fuzzer validation. |
| **Coordinated Disclosure** | **Upon patch release** | Publish release containing the fix, post GitHub Security Advisory, and credit the reporter. |

### Remediation Workflow

1. **Private Reproduction**: The issue is reproduced in an isolated test harness with regression tests added to the test suite.
2. **Hardened Patch**: The fix is developed adhering to the project's zero-cost abstraction, memory safety, and boundary invariants.
3. **Differential Audit**: The patch undergoes internal code review and fuzzing validation against golden corpora.
4. **Advisory & Release**: A patched release is distributed via GitHub Releases and the Mac App Store, followed by a public advisory with proper CVE identifiers (if requested).

---

## Core Security Invariants

TTZip enforces several architectural invariants across its native C and Swift engine layers:

### 1. Path Traversal & Symlink Hijacking Defense
- **POSIX AT-API & Safe Flags**: All archive extractions enforce `ARCHIVE_EXTRACT_SECURE_SYMLINKS`, `ARCHIVE_EXTRACT_SECURE_NODOTDOT`, and `ARCHIVE_EXTRACT_NO_OVERWRITE` flags where appropriate.
- **TOCTOU Immunity**: Directory traversal and extraction utilize reverse fixup writebacks and `O_NOFOLLOW` descriptor resolution to prevent Time-of-Check to Time-of-Use symbolic link hijacking.

### 2. Memory Zeroing & Sensitive Data Protection
- **Dead-Store Elimination Defense**: Encryption keys, derived passwords, and sensitive cryptographic buffers are erased using volatile function pointers (`secure_zero_memory`, `memset_v`, or `memset_s`) to ensure the compiler cannot optimize away memory wipe operations.
- **Lifetime Isolation**: Key material is strictly scoped in memory and zeroed immediately after cipher initialization.

### 3. Buffer Safety & Bounds Verification
- **SSIZE_MAX Clamping**: All 64-bit offsets and size computations passed between Swift and C bridge layers are clamped against integer overflow.
- **Struct Magic Validation**: Internal C handle pointers contain magic headers verified on entry and cleared on deallocation to prevent use-after-free or double-free bugs.

### 4. Sandboxing & Process Isolation
- **App Sandbox Conformance**: In MAS builds (`-DMAS_BUILD`), all operations strictly respect macOS App Sandbox container boundaries.
- **In-Process C Engine**: TTZip uses 100% in-process C static library bindings with zero shell-out or external CLI sub-process invocations.
