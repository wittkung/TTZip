# libarchive 黄金预言机测试哲学与质量保证体系指南 (libarchive Golden Oracle & QA Philosophy)

> **文档版本**: 1.0.0 | **创建日期**: 2026-08-16 | **分析基线**: `Vendor/libarchive-upstream/libarchive/test/` & `test_utils/`  
> **适用范围**: TTZip 全量测试体系、C 桥接层单元测试、跨工具差分校验与持续模糊测试

---

## 目录
1. [引言与测试哲学核心原则](#1-引言与测试哲学核心原则)
2. [零依赖两阶段宏元编程测试框架](#2-零依赖两阶段宏元编程测试框架)
3. [物理沙盒隔离与测试环境纯净化](#3-物理沙盒隔离与测试环境纯净化)
4. [UUEncoded 历史缺陷黄金语料库机制](#4-uuencoded-历史缺陷黄金语料库机制)
5. [跨生态双向差分测试矩阵](#5-跨生态双向差分测试矩阵)
6. [变异模糊测试与崩溃优先落盘哲学](#6-变异模糊测试与崩溃优先落盘哲学)
7. [TTZip 测试套件对比与四阶段演进路线图](#7-ttzip-测试套件对比与四阶段演进路线图)

---

## 1. 引言与测试哲学核心原则

在基础软件系统（如归档与解压缩引擎）的工程实践中，测试不仅是验证“代码是否可用”的工具，更是**防止历史 Bug 幽灵复活的物理防线**与**保障多生态工具互操作性的唯一依据**。

libarchive 的测试体系确立了三大核心哲学：
1. **零外部依赖自包含 (Zero External Dependencies)**：不依赖 GTest、Catch2 等外部测试框架，仅靠几百行 C 宏实现完整的测试收集与分发。
2. **不可篡改的黄金缺陷语料 (Immutable Golden Oracle Corpus)**：所有历史 CVE、格式边界、非标畸形样本全部转为纯文本 ASCII UUEncode 入库，作为永久的客观行为预言机。
3. **双向生态差分验证 (Bidirectional Differential Verification)**：不自嗨于“自己写的代码能解开自己压的文件”，而是与 GNU tar、Info-ZIP、Solaris pax 等数十种外部工具进行交叉互解。

---

## 2. 零依赖两阶段宏元编程测试框架

### 2.1 两阶段宏展开用例注册 (Two-Phase Metaprogramming)
libarchive 构建系统（Makefile/CMake）通过扫描源文件自动生成包含所有测试名称的 `list.h`：

```c
/* 第一阶段：在 test_main.c 中声明函数原型 */
#undef DEFINE_TEST
#define DEFINE_TEST(name) void name(void);
#include "list.h"

/* 第二阶段：在 test_main.c 中构建测试元数据分发数组 */
#undef DEFINE_TEST
#define DEFINE_TEST(n) { n, #n, 0 },
static struct test_list_t tests[] = {
    #include "list.h"
};
```
- **工程收益**：编写新测试用例只需在源文件中写 `DEFINE_TEST(test_read_format_zip_mycase)`，构建系统自动探测，零手动注册样板代码。

### 2.2 上下文级联断言体系
- **`failure(...)` 暂存宏**：
  ```c
  failure("Testing archive entry %d, filename: %s", entry_index, entry_path);
  assertEqualIntA(a, ARCHIVE_OK, archive_read_next_header(a, &entry));
  ```
  `failure()` 仅在断言失败时打印上下文描述，在测试通过时保持零开销。
- **`assertEqualIntA` 自动错误提取**：
  若断言失败且首参数为 `struct archive *a`，测试框架自动调用 `archive_errno(a)` 和 `archive_error_string(a)` 并格式化输出，无需手写繁琐的调试拼接。

---

## 3. 物理沙盒隔离与测试环境纯净化

每个用例在执行前（`test_run` 函数）均经历严格的环境纯净化：

1. **单用例独立沙盒目录**：在系统临时目录下创建 `testworkdir = tmpdir/tests[i].name`，`assertMakeDir(testworkdir, 0755)` 并 `assertChdir(testworkdir)`。
2. **C Locale 强制重置**：显式执行 `setlocale(LC_ALL, "C")` 与 `LANG="C"`，清除宿主机的时区与区域设置对字符串比较的干扰。
3. **Umask 快照与恢复**：执行前捕获 `oldumask = umask(0)`，测试结束后无条件复原。
4. **非特权用户降级 (`RUN_TEST_UNPRIV`)**：在支持的系统上降权为 `nobody` 用户，真实测试 ACL 与文件系统越权拦截。

---

## 4. UUEncoded 历史缺陷黄金语料库机制

### 4.1 为什么采用 UUEncode 文本持久化？
- **避免 Git 二进制膨胀**：二进制文件在 Git 中每次微小变动均产生完整快照，且跨平台检出容易因 CRLF 换行符转换而损坏。
- **自包含微型解码器**：`test_main.c` 内置 50 行纯 C 的 `extract_reference_file()`，测试运行时将 `.uu` 文件秒级解码还原至测试沙盒。

### 4.2 历史缺陷语料库沉淀矩阵
libarchive 仓库内累积了 200 余个黄金缺陷样本，每一个都对应一次 CVE 或重大兼容修复：
- `test_compat_zip_3.zip.uu`：WinZip 在文件末尾标记 length-at-end 的兼容解析。
- `test_compat_gtar_2.tar.uu`：GNU tar 超过 2097152 的 base256 格式 UID/GID 解析。
- `test_read_format_7zip_malformed_numfiles_oom.7z.uu`：超大虚假条目数诱发 OOM 的防御。
- `test_read_format_rar5_data_ready_pointer_leak.rar.uu`：RAR5 指针悬垂回归测试。

---

## 5. 跨生态双向差分测试矩阵

```
               ┌───────────────────────────────┐
               │    TTZip / libarchive 压缩    │
               └───────────────┬───────────────┘
                               │ 生成归档
                               ▼
               ┌───────────────────────────────┐
               │      物理归档文件 (Zip/Tar)    │
               └───────┬───────────────┬───────┘
                       │               │
        ┌──────────────┘               └──────────────┐
        ▼ 外部工具解压                                ▼ 自身引擎解压
┌───────────────────────────────┐      ┌───────────────────────────────┐
│ 系统原生 /usr/bin/unzip, tar  │      │   TTZip Parallel Extractor    │
└───────────────┬───────────────┘      └───────────────┬───────────────┘
                │ 提取文件                             │ 提取文件
                ▼                                      ▼
┌──────────────────────────────────────────────────────────────┐
│            SHA-256 逐字节差分与元数据严格一致性校验           │
└──────────────────────────────────────────────────────────────┘
```

- **双向验证要求**：
  1. 自身引擎生成的压缩包必须能被外部成熟工具（macOS 系统 `tar`、`unzip`、7-Zip 官方二进制）无损解压。
  2. 外部工具生成的历史标准样本必须能被自身引擎 100% 正确解析。

---

## 6. 变异模糊测试与崩溃优先落盘哲学

### 6.1 `test_fuzz.c` 轻量模糊测试机制
- **变异算法**：加载合法归档，注入 ~1% 伪随机单字节扰动（`image[rand() % size] = (char)rand()`）。
- **崩溃优先落盘 (Crash-First Disk Persistence)**：
  ```c
  /* 关键模式：在调用解析前，先将破坏后的图像写入固定文件 */
  f = fopen("after.test.failure.send.this.file.to.maintainers", "wb");
  fwrite(image, 1, size, f);
  fclose(f);
  ```
  若后续调用触发 SIGSEGV 或 ASan 报错，进程崩溃后该文件即刻留存为现成的最小复现用例（Reproducer）。
- **双模式消费验证**：
  - Pass 1：遍历 Header 并全量解压 Body。
  - Pass 2：仅遍历 Header 并显式 Skip Body，验证快进跳跃与状态机容错。

---

## 7. TTZip 测试套件对比与四阶段演进路线图

### 7.1 对比矩阵

| 维度 | libarchive-upstream | TTZip 现状 | 演进建议 |
| :--- | :--- | :--- | :--- |
| **测试框架** | 纯 C，零依赖宏展开 | Swift XCTest (525+ tests) | 保持 Swift 测试现代化优势，针对 C 桥接层补充纯 C 轻量级白盒测试。 |
| **性能门禁** | 无自动化吞吐门禁 | **全格式 46 项历史最优硬门禁** (10% 倒退阻断) | 保持 TTZip 业界顶级的性能门禁纪律。 |
| **黄金语料库** | 200+ UUEncoded 历史缺陷样本 | 10 个静态加密测试包 | 将 upstream 关键 `.uu` 样本引入 TTZip，建立历史缺陷全量回归。 |
| **模糊测试** | 内建随机变异 Fuzzer + 崩溃预转储 | 基于固定规则的边界测试 | 引入 In-Process 变异模糊测试与崩溃现场优先落盘机制。 |
| **差分测试** | 针对 GNU tar/Star/Info-ZIP 差分 | 内部 Swift 与 C 桥接对比 | 建立针对 macOS 系统 `/usr/bin/tar`、`/usr/bin/unzip` 的自动化跨进程差分测试。 |

### 7.2 四阶段演进实施路线图

1. **第一阶段：UUEncode 黄金缺陷语料库集成**
   - 将 upstream 关键 `.uu` 样本同步至 TTZip 测试资产，实现内存解码器，建立 `GoldenCorpusTests.swift`。
2. **第二阶段：In-Process 变异模糊测试门禁**
   - 实现 `ArchiveMutationFuzzTests.swift`，每次 CI 运行 500 次轻量变异解压循环，先落盘复现文件再解析，断言零 Crash。
3. **第三阶段：macOS 系统工具跨进程差分校验**
   - 实现 `SystemDifferentialTests.swift`，验证 TTZip 打包的文件可被 `/usr/bin/tar`、`/usr/bin/unzip` 完美解压。
4. **第四阶段：上下文级联诊断包装器**
   - 在 Swift 测试中实现 `withFailureContext("Entry: \(name)") { ... }`，大幅提升复杂归档测试失败时的定位效率。
