# TTZip 工业级系统工程方法论与心智模型指南 (Systemic Engineering Methodology)

> **版本**: 1.0.0 | **密级**: 核心工程标准 | **适用对象**: TTZip 核心引擎开发者、系统架构师与 AI 协作 Agent

---

## 目录

1. [引言：高级语言思维与系统工程思维的代差](#一-引言高级语言思维与系统工程思维的代差)
2. [铁律一：流式第一性 (Stream-First)](#二-铁律一流式第一性-stream-first)
3. [铁律二：纵深防御 (Invariant-First)](#三-铁律二纵深防御-invariant-first)
4. [铁律三：确定性确界 (Bounds-First)](#四-铁律三确定性确界-bounds-first)
5. [铁律四：真实预言机 (Oracle-First)](#五-铁律四真实预言机-oracle-first)
6. [系统级反模式案例库 (Anti-Patterns Library)](#六-系统级反模式案例库-anti-patterns-library)
7. [日常开发与审查检查清单 (Review Checklist)](#七-日常开发与审查检查清单-review-checklist)

---

## 一、 引言：高级语言思维与系统工程思维的代差

在 Web、应用层（SwiftUI / React / AppKit）开发中，开发者习惯了高级语言带来的抽象便利：垃圾回收/自动引用计数（ARC）、动态容器（`Array`, `Data`, `Dictionary`）、面向对象对象树（Composite / Visitor）以及内存无限的假设。

然而，在**底层归档、存储与压缩解压引擎**（如 `libarchive`、`TTZipCore`、`CTTZipBridge`）中，这些习惯会直接转化为灾难性的系统级缺陷：

```
高级应用思维 (High-Level App Mindset)      工业级系统思维 (Industrial Systems Mindset)
───────────────────────────────────      ────────────────────────────────────────
• 假设内存无限 (读入整个文件/对象)       ➔  • 零内存假设 (内存恒定在微缓冲 64KB~2MB)
• 上层正则/黑名单过滤 (防君子不防小人)    ➔  • 下沉至 POSIX / 内核原子原语 (物理不可破)
• 依赖 ARC/托管，调用 free 即结束         ➔  • 怀疑主义与确定性确界 (Magic 哨兵与清零)
• 自产自销的单元测试 (同义反复)           ➔  • 真实缺陷语料库 + 跨生态差分测试 (客观预言机)
```

本指南旨在确立 TTZip 的**四大系统工程铁律**，帮助团队在心智模型上实现从“应用开发者”到“工业级系统工程师”的彻底跃迁。

---

## 二、 铁律一：流式第一性 (Stream-First)

### 1. 核心心法：零内存假设与拉取模型
无论待处理的归档文件是 $1\text{ KB}$ 还是 $100\text{ GB}$，引擎的工作内存必须保持在**极小的常数级区间**（如 $64\text{ KB} \sim 128\text{ MB}$）。

### 2. 微缓冲解耦机制
- **Lookahead (`__archive_read_ahead`)**：返回当前缓冲区内至少包含 $N$ 字节的连续只读指针，**绝对不移动流指针**。当请求数据已在当前块中时，实现 100% 零拷贝直通。
- **Consume (`__archive_read_consume`)**：显式推进流指针，支持按需消费。

### 3. 严禁内核零填充中断 (Zero-Fill Page Faults)
- **反模式**：在热循环中使用 `var buffer = Data(count: size)`。Swift 的 `Data(count:)` 内部触发操作系统内核对物理页清零，浪费大量 CPU 周期并污染 CPU 缓存。
- **正确范式**：使用未初始化裸指针：
  ```swift
  let ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
  // 解压函数直接覆写物理内存
  ttzip_decompress(src, count, ptr, size)
  return Data(bytesNoCopy: ptr, count: actualSize, deallocator: .custom({ p, _ in p.deallocate() }))
  ```

---

## 三、 铁律二：纵深防御 (Invariant-First)

### 1. 核心心法：安全策略下沉至系统调用层
任何在 Swift 业务层进行的字符串检查（如 `contains("..")`）都可能被编码绕过、软链接跳跃或并发竞态（TOCTOU）突破。安全必须建立在**内核原语层**。

### 2. POSIX 原语原子性防御
- **AT-API 逐级符号链接阻断**：解压落盘必须配置 `ARCHIVE_EXTRACT_SECURE_SYMLINKS`、`ARCHIVE_EXTRACT_SECURE_NODOTDOT` 与 `ARCHIVE_EXTRACT_SECURE_NOABSOLUTEPATHS`。在底层利用 `fstatat(..., AT_SYMLINK_NOFOLLOW)` 逐级探测路径对象，发现中间符号链接立即抛出 `ELOOP` 熔断。
- **延后 Fixup 倒序回写**：
  - 中间目录先以 `0700` 临时创建；
  - Close 阶段按深度**从深到浅（Depth-First）倒序回写**只读权限与 mtime；
  - 回写前使用 `open(..., O_NOFOLLOW | O_DIRECTORY)` 校验 inode 类型，彻底消除并发软链接替换劫持。

### 3. 硬件级防溢出算术
所有跨语言传递的 64 位整数向 `size_t` 窄化前强制 `SSIZE_MAX` Clamp；缓冲区乘加优先调用 `__builtin_add_overflow` / `__builtin_mul_overflow`。

---

## 四、 铁律三：确定性确界 (Bounds-First)

### 1. 核心心法：显式闭环与全生命周期防毒化
不能假设调用了 `free()` 指针就不再被访问。必须假设任何悬垂指针都可能被非法调用。

### 2. Magic 结构体哨兵
- 结构体首成员必须是 `uint32_t magic`。
- 构造时填入唯一魔数（如 `TTZIP_MAGIC`）。
- API 入口执行单周期位掩码校验：`if (a->magic != TTZIP_MAGIC) return TTZIP_FATAL;`。
- **析构清零**：在 `free(a)` 前强制执行 `a->magic = 0;`，使 Use-After-Free 立即被入口捕获。

### 3. 敏感内存物理擦除
密码、派生密钥与解密中间状态在释放前必须调用 `memset_s` / `explicit_bzero` 写入物理内存，严禁使用易被编译器死代码消除（Dead-Store Elimination）的普通 `memset`。

---

## 五、 铁律四：真实预言机 (Oracle-First)

### 1. 核心心法：真实世界是唯一的黄金标准
杜绝“自写压缩器 $\to$ 自写解压器 $\to$ 断言通过”的同义反复自嗨。

### 2. 真实缺陷语料库 (UUEncode Corpus)
将 20 余年工业界积累的 CVE 样本、极端边界样本（Zip64 4GiB、RAR5 悬垂指针、7z 畸形头部）以 ASCII `.uu` 文本文件入库，由 `UUDecoder` 在内存中秒级还原，建立不可篡改的黄金预言机。

### 3. 跨生态双向差分测试 (Differential Testing)
自研引擎生成的归档必须能被系统原生 `/usr/bin/tar` 与 `/usr/bin/unzip` 完美解压；系统工具生成的归档必须能被自身正确读取。

### 4. 崩溃现场优先模糊测试 (Crash-First Fuzzing)
在将 1% 随机变异数据传入解析器前，**必须先将样本落盘至沙盒调试文件**（`fuzz_crash_reproducer.bin`），一旦触发底层段错误可秒级获得最小复现用例。

---

## 六、 系统级反模式案例库 (Anti-Patterns Library)

| 场景 | 典型反模式 (Anti-Pattern) | 工业级正解 (Best Practice) |
| :--- | :--- | :--- |
| **超大 Solid 压缩** | 一次性 `posix_memalign` 分配全部 50GB 文件大小 | 基于 32MB/64MB 滑动窗口的分块流式 Solid 管道 |
| **解压缓冲区分配** | `var buf = Data(count: size)` 产生内核物理页清零 | `UnsafeMutablePointer.allocate` + `Data(bytesNoCopy:)` |
| **路径穿越防御** | 仅在 UI 侧用黑名单检查 `.exe` 或字符串正则 | C 桥接层下沉配置 `ARCHIVE_EXTRACT_SECURE_SYMLINKS` |
| **密码临时缓冲区** | `memset(pass, 0, len); free(pass);` 被编译器优化掉 | `memset_s(pass, len, 0, len); free(pass);` |
| **测试套件构造** | 仅构造简单的几个合法 Mock 归档自测 | 引入 upstream `.uu` 历史缺陷库与系统 CLI 差分对比 |

---

## 七、 日常开发与审查检查清单 (Review Checklist)

- [ ] **Stream Check**: 是否存在假设内存无限的 `malloc(total_file_size)`？
- [ ] **Zero-Fill Check**: 热循环中是否出现了 `Data(count:)`？
- [ ] **Path Safety Check**: 解压写盘是否启用了 `SECURE_SYMLINKS` 与 `SECURE_NOABSOLUTEPATHS`？
- [ ] **Magic Check**: 导出的 C 结构体在 `free()` 前是否执行了 `magic = 0`？
- [ ] **Credential Wipe Check**: 密码释放前是否调用了 `memset_s`？
- [ ] **Oracle Check**: 新格式/功能是否有系统 CLI 差分测试或真实边界样本覆盖？
