# 上游开源贡献全维度经验复盘与工程实践白皮书 (Lessons Learned & SOP)

> **归档日期**：2026-08-17  
> **涉及仓库**：`libarchive/libarchive` (PR #3391, PR #3388, PR #3393, Issue #3392)  
> **核心维护者**：Tim Kientzle (`@kientzle`), Martin Stoeckmann (`@stoeckmann`), Dustin Howett (`@DHowett`)

---

## 目录

1. [背景与复盘契机](#一背景与复盘契机)
2. [六大核心经验与根因剖析](#二六大核心经验与根因剖析)
   - [经验 1：双构建系统（Dual-Build System）的物理双向验证](#经验-1双构建系统dual-build-system的物理双向验证)
   - [经验 2：C 语言严格原型约束 (`-Wmissing-prototypes`)](#经验-2c-语言严格原型约束--wmissing-prototypes)
   - [经验 3：预处理条件编译的注释排版规范（BSD/KNF 惯例）](#经验-3预处理条件编译的注释排版规范bsdknf-惯例)
   - [经验 4：性能基准测试的科学可复现性规范](#经验-4性能基准测试的科学可复现性规范)
   - [经验 5：开源社区治理机制与 Issue-First / Draft 隔离](#经验-5开源社区治理机制与-issue-first--draft-隔离)
   - [经验 6：顶级 Maintainer 协作礼仪与谦逊沟通](#经验-6顶级-maintainer-协作礼仪与谦逊沟通)
3. [固化工具与自动化防御资产](#三固化工具与自动化防御资产)
4. [上游贡献 15 项终极 Pre-Flight 检查清单](#四上游贡献-15-项终极-pre-flight-检查清单)

---

## 一、 背景与复盘契机

在向主流 C 基础库 `libarchive` 贡献三项核心特性的过程中，我们经历了从“单侧验证假象”到“全矩阵物理闭环”的认知与工程跃迁：
- **PR #3391 (CRC32)**：在 CMake 下全绿，但在 GNU Autotools 下漏注册 `Makefile.am` 导致符号缺失；在 FreeBSD 严格模式下缺少 `#include "archive_private.h"` 触发 `-Wmissing-prototypes`；注释写在 `#if` 外部不符合排版习惯。
- **PR #3388 (7-Zip AES)**：单 Commit 粒度过大被 Reviewer 要求拆分；敏感内存需使用 `volatile` 防死存储消除。
- **PR #3393 (Preallocate)**：因 Issue 未完全达成共识先提 PR 触发了 Collaborator 的流程性 Block；后经 Tim 质询性能实测，通过高精度物理实测完成数据支撑。

---

## 二、 六大核心经验与根因剖析

### 经验 1：双构建系统（Dual-Build System）的物理双向验证
* **问题现象**：我们在本地仅运行了 `cmake` 构建，未运行 GNU `autotools`，导致 `Makefile.am` 未添加新增的 `.c` 文件，Maintainer 在 macOS/Linux 上执行 Autotools 构建时链接失败。
* **根因剖析**：单侧工具链带来“通过的虚假安全感”。大型 C 开源库（如 libarchive、curl、ffmpeg）为了跨系统分发，通常并行维护 CMake 与 Autotools。
* **铁律与防线**：
  1. 任何新增 `.c` 文件，**必须同时**加入 `CMakeLists.txt` 与 `Makefile.am`；
  2. 提交前必须在本地执行 `./build/autogen.sh && ./configure && make libarchive.la && make check`；
  3. 运行静态一致性检查工具 `scripts/audit_dual_build.py` 自动化断言源文件列表 100% 相同。

---

### 经验 2：C 语言严格原型约束 (`-Wmissing-prototypes`)
* **问题现象**：`archive_crc32.c` 中定义了全局函数 `__archive_crc32()`，但文件顶部未 `#include "archive_private.h"`。在 FreeBSD Clang 开启 `-Wmissing-prototypes -Werror` 时构建阻断。
* **根因剖析**：C 编译器在未见全局函数前置声明时，无法核验实现与原型的签名一致性。
* **铁律与防线**：
  - 每一个 `.c` 实现文件必须显式引入声明了其导出的内部私有头文件；
  - 本地 CMake 验证必须开启强制参数：`-DCMAKE_C_FLAGS="-Wmissing-prototypes -Wall -Wextra" -DENABLE_WERROR=ON`。

---

### 经验 3：预处理条件编译的注释排版规范（BSD/KNF 惯例）
* **问题现象**：在 `#if` / `#elif` / `#else` 多分支条件编译中，将实现描述注释写在了宏指令的前面（外部）。
* **Maintainer 指导**：*“Comments should go immediately after the `#if`/`#elif`/`#else`, not before. (That is, within the relevant preprocessor block, along with the code they describe.)”*
* **规范范式**：
  ```c
  /* ❌ 错误示范：注释在宏外面 */
  /* Implementation 1: Hardware */
  #if defined(__aarch64__)
  ...
  /* Implementation 2: zlib */
  #elif defined(HAVE_ZLIB_H)
  ...
  #endif

  /* 🟢 正确规范：注释在宏内部紧随其后 */
  #if defined(__aarch64__)
  /* Implementation 1: Hardware-accelerated CRC32 using ARMv8 ACLE */
  ...
  #elif defined(HAVE_ZLIB_H)
  /* Implementation 2: zlib crc32() */
  ...
  #else
  /* Implementation 3: Portable 256-entry table fallback */
  ...
  #endif
  ```

---

### 经验 4：性能基准测试的科学可复现性规范
* **问题现象**：在讨论性能优化时，空泛的“理论加速”无法说服顶级 Maintainer。
* **科学规范**：汇报 Benchmark 时必须完整包含 **六大物理规格维度**：
  1. **CPU & 架构**：精确到型号与核心数（如 `Apple M5 Max, 18-core`）；
  2. **内存与存储**：内存容量与底层文件系统类型（如 `128 GB Unified Memory`, `Apple APFS on Internal NVMe SSD`）；
  3. **操作系统版本**：精确到内核版本（如 `macOS Darwin 25.6.0`）；
  4. **编译器与标志**：精确到版本与优化级别（如 `Apple Clang 21.0.0 (-O3)`）；
  5. **单调时钟源**：必须使用 `clock_gettime(CLOCK_MONOTONIC)`，排除时区与 NTP 抖动；
  6. **差分数据矩阵**：多轮循环取均值，给出不同数据规模下的真实耗时、吞吐量（MB/s）与 $\Delta\%$。

---

### 经验 5：开源社区治理机制与 Issue-First / Draft 隔离
* **协作法则**：
  1. **Issue 先行**：重大 Feature 必须先开 Issue 讨论必要性与设计，绝不以 PR 强行抢跑；
  2. **Draft 隔离**：在 Maintainer 达成共识前，PR 必须标为 `Draft`，避免占用 Maintainer 正常 review 队列并触发流程性 Block；
  3. **防御性优雅降级 (Graceful Fallback)**：引入平台特有系统调用时，必须设计非致命降级路径（如 `F_PREALLOCATE` 失败自动退化为标准流式写入），彻底消除破坏兼容性的顾虑。

---

### 经验 6：顶级 Maintainer 协作礼仪与谦逊沟通
* **沟通黄金法则**：
  1. **真诚致谢**：开篇感谢 Maintainer 跨平台测试和审查付出的宝贵时间；
  2. **逐项闭环 (Itemized Resolution)**：对 Review 意见逐条列出解决方案与本地验证事实，杜绝模糊回答；
  3. **纯粹事实，拒绝修辞**：用客观工程语言（如 `Key Observations & Takeaways`）取代戏剧化隐喻；
  4. **开放心态**：结尾主动表示乐意根据 Maintainer 的想法开展进一步实验或调整。

---

## 三、 固化工具与自动化防御资产

为确保上述经验永久成为团队的无意识肌肉记忆，我们已落盘以下资产：

1. **双构建系统静态一致性审计工具**：
   - 脚本路径：[`Vendor/worktrees/libarchive/pr-3391-crc32/scripts/audit_dual_build.py`](file:///Users/kevintung/Documents/dev/TTZip/Vendor/worktrees/libarchive/pr-3391-crc32/scripts/audit_dual_build.py)
   - 作用：自动化对比 `Makefile.am` 与 `CMakeLists.txt` 的源文件列表，漏加源文件即报错退出。
2. **物理预分配微基准测试工具**：
   - 源码路径：[`scripts/bench_preallocate.c`](file:///Users/kevintung/Documents/dev/TTZip/scripts/bench_preallocate.c)
   - 作用：基于 `CLOCK_MONOTONIC` 测量 APFS / Linux fallocate 的真实吞吐增益与快速失败表现。
3. **全局规则与技能更新**：
   - [`GEMINI.md`](file:///Users/kevintung/Documents/dev/TTZip/GEMINI.md)：写入 §5.5 双构建系统全量物理验证与原型确界。
   - [`.agents/skills/upstream-contribution/SKILL.md`](file:///Users/kevintung/.agents/skills/upstream-contribution/SKILL.md)：写入 Pre-Flight Checklist 强制双构建验证与 BSD 注释排版要求。

---

## 四、 上游贡献 15 项终极 Pre-Flight 检查清单

向外部开源仓库提交任何代码前，必须无条件逐项确认勾选：

- [x] **1. Git 纯净分支**：从 `origin/master` 纯净检出，`git diff upstream/master..HEAD --stat` 零无关文件污染。
- [x] **2. 原子 Commit 序列**：严格遵循 `infra` → `feat` → `test` 拆分，每个 commit 独立可编译。
- [x] **3. 双构建源文件注册**：`Makefile.am` 与 `CMakeLists.txt` 源文件 100% 同步并通过 `audit_dual_build.py`。
- [x] **4. CMake 严格模式编译**：`-DCMAKE_C_FLAGS="-Wmissing-prototypes -Wall -Wextra" -DENABLE_WERROR=ON` 零警告。
- [x] **5. Autotools 编译与测试**：`./build/autogen.sh && ./configure && make libarchive.la && make check` 全量通过。
- [x] **6. 严格原型包含**：每个 `.c` 文件顶部显式 `#include` 声明其导出的私有头文件。
- [x] **7. 注释排版合规**：条件编译说明注释置于 `#if` / `#elif` / `#else` 内部紧随其后。
- [x] **8. 敏感内存防死存储**：密钥与密码清理使用 `volatile` 函数指针或 `memset_s`。
- [x] **9. 跨架构整型与溢出安全**：64-bit 偏移量转 `size_t` 经过 32 位安全 Clamp，防御短读取与空指针。
- [x] **10. 原生预言机对齐**：测试使用原生算法（如 `bitcrc32()`）作为黄金基准，严禁外部硬编码常量。
- [x] **11. 启发式内置与反配置膨胀**：默认通过客观条件（如 $\ge 64\text{KB}$）透明决策，不随意增加公开 Option Flag。
- [x] **12. 防御性优雅降级**：新系统调用失败时安全 fallback 到标准实现，不阻断解压主流程。
- [x] **13. 真实物理 Benchmark**：汇报性能必须附带 CPU、RAM、OS、文件系统、编译器与单调时钟规格。
- [x] **14. Issue-First 敬畏**：新特性先在 Issue 讨论，PR 在达成共识前显式标记为 Draft。
- [x] **15. 谦逊与礼仪表达**：逐项客观闭环回复，真诚致谢 Maintainer 的时间与指导。
