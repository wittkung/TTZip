# libarchive 工业级工程卓越性与架构设计哲学全景报告 (libarchive Engineering Excellence & Architectural Synthesis)

> **文档版本**: 1.0.0 | **创建日期**: 2026-08-16 | **分析基线**: `Vendor/libarchive-upstream` (v3.7.x+)  
> **适用范围**: TTZip 核心引擎、C 桥接层、Swift 6 架构抽象及跨仓库基础设施

---

## 目录
1. [引言与核心价值](#1-引言与核心价值)
2. [C 语言面向对象多态与结构体继承布局](#2-c-语言面向对象多态与结构体继承布局)
3. [双向流式过滤器流水线与竞标协议 (Bidding Protocol)](#3-双向流式过滤器流水线与竞标协议-bidding-protocol)
4. [微缓冲机制 (Micro-Buffering) 与零拷贝直通架构](#4-微缓冲机制-micro-buffering-与零拷贝直通架构)
5. [位掩码状态机与单调错误传播体系](#5-位掩码状态机与单调错误传播体系)
6. [工业级安全防御与漏洞免疫矩阵](#6-工业级安全防御与漏洞免疫矩阵)
7. [对 TTZip 与现代 C-Swift 引擎的架构启示与落地准则](#7-对-ttzip-与现代-c-swift-引擎的架构启示与落地准则)

---

## 1. 引言与核心价值

`libarchive` 是全球主流操作系统（macOS `bsdtar`/`libarchive.dylib`、FreeBSD 原生基础库、Debian、Windows 11 归档支持）与基础设施中最核心的归档与压缩解压底层库。

其历经二十余年演进，在以下关键工程维度形成了卓越的工业级标准：
- **极致的跨平台可移植性**：纯 C89/C99 实现，严格遵循 POSIX 标准，同时无缝兼容 Windows、BSD 和嵌入式环境。
- **流式抽象与自底向上组装**：通过竞标协议（Bidding Protocol）实现格式嗅探与解压过滤器的全自动动态级联装配。
- **零拷贝与微缓冲调度**：将 Lookahead（预读）与 Consume（推进）正交解耦，在块边界内实现 100% 零拷贝直通。
- **无懈可击的安全防御体系**：AT-API 逐级符号链接防御、深度优先倒序权限回写（Fixup）、硬件级防溢出安全算术以及严密的解压炸弹熔断。

本文档全面解构其架构设计、内存模型与防御范式，为 TTZip 及其关联底层仓库提供可落地的工程基准。

---

## 2. C 语言面向对象多态与结构体继承布局

### 2.1 首成员物理继承 (Single-Root Inheritance via First Member)
libarchive 使用纯 C 结构体布局规范实现了零运行时开销的单继承多态体系：

```c
/* 基类定义 (archive_private.h) */
struct archive {
    unsigned int           magic;            /* 句柄魔数校验 */
    unsigned int           state;            /* 位掩码状态机 */
    struct archive_vtable *vtable;           /* 统一顶层虚表指针 */
    int                    archive_format;   /* 当前归档格式 ID */
    int                    file_count;       /* 处理条目计数 */
    int                    archive_error_number;
    struct archive_string  error_string;     /* 动态错误描述缓冲 */
};

/* 派生类定义 (archive_read_private.h) */
struct archive_read {
    struct archive archive;                  /* 首成员物理内嵌基类 */
    struct archive_entry *entry;
    struct archive_read_filter *filter;     /* 过滤器流水线头节点 */
    struct archive_format_descriptor *format;/* 锁定的格式处理器 */
    struct archive_read_filter_bidder bidders[16]; /* 静态注册槽位 */
    struct archive_format_descriptor formats[16];
    /* ... 内部缓冲区与私有状态 ... */
};
```

- **物理内存特性**：`struct archive_read *a` 的内存首地址与 `&(a->archive)` 严格相同。
- **向上类型转换**：调用公共 API 时，可安全无损地执行 `(struct archive *)a_read`，无需额外的虚基类偏移计算。

### 2.2 双层虚函数派发体系 (Two-Tiered Virtual Dispatch)

```
[ Public API: archive_read_next_header(a, &entry) ]
                         │
                         ▼
        ┌───────────────────────────────────┐
        │  Tier 1: a->vtable->read_header   │ ◄── archive_virtual.c (顶层引擎虚表)
        └───────────────────────────────────┘
                         │
                         ▼
        ┌───────────────────────────────────┐
        │ Tier 2: a->format->read_header    │ ◄── 格式策略虚表 (ZIP/7z/TAR/RAR5)
        └───────────────────────────────────┘
```

1. **Tier 1 (顶层引擎虚表 `struct archive_vtable`)**：
   - 统一抽象：`archive_close`、`archive_free`、`archive_read_next_header`、`archive_read_data_block`、`archive_write_header`、`archive_write_data`。
   - 职责：维护状态机校验，中继派发到底层具体策略。
2. **Tier 2 (策略虚表 `struct archive_format_descriptor` & `filter_vtable`)**：
   - 包含格式与过滤器专属的生命周期：`bid`, `init`, `read_header`, `read_data`, `read_data_skip`, `seek_data`, `cleanup`。

### 2.3 零堆分配静态槽位注册 (Static Slot Array)
libarchive 摒弃了动态链表注册机制，在 `struct archive_read` 内部固定分配 16 个槽位的静态数组：
```c
struct archive_read_filter_bidder bidders[16];
struct archive_format_descriptor formats[16];
```
- **工程价值**：完全消除模块注册时的动态内存分配；解构时无需处理复杂链表指针析构；支持编译期剥离未使用的格式源文件。

---

## 3. 双向流式过滤器流水线与竞标协议 (Bidding Protocol)

### 3.1 自底向上的竞标协议流转

```
[ Client Stream I/O Callbacks (read/skip/seek) ]
                       │
                       ▼ (Base Filter: none_reader_vtable)
           ┌────────────────────────┐
           │   choose_filters()     │ ◄── 遍历 bidders[16]，调用 bidder->bid()
           └────────────────────────┘
                       │  (胜出者挂载为新 head: f->upstream = current_head)
                       ▼
           [ Gzip / Zstd / Bzip2 / ... Filter ]
                       │  (最高支持 25 层过滤器级联，如 .tar.gz.uu)
                       ▼
           ┌────────────────────────┐
           │    choose_format()     │ ◄── 遍历 formats[16]，在解压平坦流上调用 format->bid()
           └────────────────────────┘
                       │  (胜出者锁定为 active format)
                       ▼
           [ Tar / Zip / 7z / Pax / ... Format Handler ]
```

1. **基础层装配**：`archive_read_open1()` 首先创建 `ARCHIVE_FILTER_NONE` 过滤器，将外部传入的 I/O 回调包装为 `none_reader_vtable`。
2. **过滤器自动竞标循环 (`choose_filters`)**：
   - 迭代上限 `MAX_NUMBER_FILTERS = 25`。
   - 遍历注册的 `bidders`，调用 `bidder->vtable->bid(bidder, a->filter)`。
   - 竞标函数通过 `__archive_read_filter_ahead()` 窥探数据流前部特征（如 Gzip 校验魔数 `\x1F\x8B\x08`），返回匹配比特数作为得分。
   - 胜出者实例化为 `struct archive_read_filter` 并建立双向链：`f->upstream = a->filter; a->filter = f;`，随后调用 `init()` 初始化解压状态机。
   - 重复竞标，直至无更高得分 Bidder。
3. **格式自动嗅探 (`choose_format`)**：
   - 在已完全解压的平坦数据流前端遍历 `formats[16]` 调用 `format->bid(a, best_bid)`。
   - 各格式检查容器魔数（如 ZIP 魔数 `PK\x03\x04` 得 29 分，TAR 得 48~106 分）。
   - 最高得分槽位锁定为活跃格式 `a->format`。

---

## 4. 微缓冲机制 (Micro-Buffering) 与零拷贝直通架构

### 4.1 Lookahead 与 Consume 正交解耦

```
                           +------------------------------------------+
                           |  __archive_read_ahead(a, min, &avail)    |
                           +------------------------------------------+
                                                |
                 +------------------------------+------------------------------+
                 | (Fast-Path: 零拷贝直通)                                      | (Slow-Path: 跨块微缓冲拼接)
                 v                                                             v
+------------------------------------+                       +------------------------------------+
| 请求尺寸位于 Client 缓冲区内       |                       | 请求跨越了底层 I/O 数据块边界      |
| (client_avail + avail >= min)      |                       |                                    |
|                                    |                       | 1. 动态安全扩容 f->buffer          |
| -> 直接返回 f->client_next 内存指针|                       |    (archive_ckd_mul_size 防溢出)   |
| -> 零 malloc、零 memcpy            |                       | 2. memmove 移动未处理碎片          |
+------------------------------------+                       | 3. memcpy 拼入新块至 f->buffer     |
                                                             +------------------------------------+
                                                |
                                                v
                           +------------------------------------------+
                           |  __archive_read_consume(a, request)      |
                           +------------------------------------------+
                                                |
                                                v
                           +------------------------------------------+
                           |  显式向前推进流指针，支持按需部分消费     |
                           +------------------------------------------+
```

1. **`__archive_read_ahead(a, min, &avail)`**：
   - 语义：保证返回至少包含 `min` 字节连续有效数据的内存指针；在 `*avail` 中返回当前缓冲区内实际可用的最大连续字节数。
   - **关键铁律：绝不移动流指针**。
2. **`__archive_read_consume(a, request)`**：
   - 语义：显式推进流指针 `request` 字节，支持部分消费。
3. **零拷贝数据输出 (`archive_read_data_block`)**：
   - 直接将底层解码缓冲区的内部指针地址传递给调用方，实现解压数据向应用层的零拷贝透传。

---

## 5. 位掩码状态机与单调错误传播体系

### 5.1 显式位掩码状态机

```c
#define ARCHIVE_STATE_NEW             0x01U    /* 对象已创建，未 open */
#define ARCHIVE_STATE_OPEN            0x02U    /* 数据源已打开 */
#define ARCHIVE_STATE_HEADER          0x04U    /* 准备就绪读取 Header */
#define ARCHIVE_STATE_DATA            0x08U    /* Header 已解析，准备读取 Body */
#define ARCHIVE_STATE_DATA_RECOVERY   0x10U    /* Header 受损，允许跳过 Body 恢复 */
#define ARCHIVE_STATE_EOF             0x20U    /* 归档流正常结束 */
#define ARCHIVE_STATE_CLOSED          0x40U    /* 归档已关闭 */
#define ARCHIVE_STATE_FATAL           0x8000U  /* 致命错误不可逆状态 */
```

- **全入口哨兵断言 (`archive_check_magic`)**：
  在所有公共 API 入口执行：
  ```c
  if ((a->state & allowed_states) == 0) {
      archive_set_error(a, -1, "Function '%s' not allowed in current state", func_name);
      a->state = ARCHIVE_STATE_FATAL;
      return (ARCHIVE_FATAL);
  }
  ```
  单次按位与运算即刻阻断乱序调用、并发竞争与状态损坏。

### 5.2 分级单调错误模型与 Errno 绑定
- **6 级错误码**：`ARCHIVE_EOF (1)`, `ARCHIVE_OK (0)`, `ARCHIVE_RETRY (-10)`, `ARCHIVE_WARN (-20)`, `ARCHIVE_FAILED (-25)`, `ARCHIVE_FATAL (-30)`。
- **单调合并原则**：宏 `#define err_combine(a, b) ((a) < (b) ? (a) : (b))` 确保灾难性错误在流水线向上冒泡时绝不被轻微告警覆盖。
- **动态错误格式化**：`archive_set_error(a, err_no, fmt, ...)` 动态格式化并绑定标准 POSIX errno。

---

## 6. 工业级安全防御与漏洞免疫矩阵

| 防御领域 | libarchive 核心防御机制 | 传统常见漏洞 | TTZip 落地规范与审查要求 |
| :--- | :--- | :--- | :--- |
| **路径清洗** | `cleanup_pathname_fsobj` 原地单遍扫描，消除 `//` 与 `./`，阻断绝对路径与 `..` 穿越，严禁静默移除。 | Zip Slip 任意文件覆盖 | 解压管道前置强制执行路径清洗，严禁使用原始未过滤路径。 |
| **符号链接防御** | `chdir_fd = la_opendirat(AT_FDCWD, ".")` 配合 `fstatat(..., AT_SYMLINK_NOFOLLOW)` 逐级探测，发现中间软链接直接拒收。 | 符号链接沙盒逃逸 (Symlink Traversal) | 严格开启 `ARCHIVE_EXTRACT_SECURE_SYMLINKS` 与 `ARCHIVE_EXTRACT_SECURE_NODOTDOT`。 |
| **TOCTOU 竞态缓解** | 目录以 `0700` 临时创建，元数据存入 Fixup 链表，在 Close 阶段按**深度从深到浅倒序回写**，回写前验证 `la_verify_filetype`。 | 解压过程动态替换目录劫持宿主文件权限 | 落地延迟权限与时间戳倒序回写机制，回写前使用 `O_NOFOLLOW` 打开句柄。 |
| **整型安全** | `archive_integer.h` 封装 `__builtin_add_overflow` / `__builtin_mul_overflow`，64 位转 `size_t` 严格 Clamp 保护。 | 整数溢出导致缓冲区回绕与堆越界 (Heap OOB) | C 桥接层禁止裸加法/乘法分配；所有 `int64` 转 `size_t` 必须使用 `SSIZE_MAX` Clamp。 |
| **解压炸弹熔断** | 过滤器链深度 $\le 25$；RAR5 解压窗口 $\le 64\text{MB}$；7z 条目数与头部剩余字节交叉校验 (`files_info_numfiles_is_sane`)。 | Zip Quine / 畸形 Header 诱发宿主系统 OOM 崩溃 | 建立单条目解压比率（$\le 1000:1$）监控与内存分配前置一致性校验。 |
| **魔数与生命周期** | 句柄首字段内嵌 Magic；析构前强制执行 `a->archive.magic = 0; __archive_clean(&a->archive);`；密码使用 `explicit_bzero` 擦除。 | Use-After-Free (UAF) / Double Free / 内存密码泄漏 | 暴露给 Swift 的 C 句柄必须内嵌 Magic 并在释放前清零；密码释放前强制内存清零。 |

---

## 7. 对 TTZip 与现代 C-Swift 引擎的架构启示与落地准则

1. **热路径零成本抽象铁律**：
   - libarchive 的 `__archive_read_filter_ahead` 证明了高性能解压必须在块边界内实现裸指针零拷贝直通。
   - TTZip 在 `ZipParallelExtractor`、`ZipParallelWriter` 和 `CTTZipBridge` 中必须杜绝在并行并发闭包内部引入动态对象封装或共享锁。
2. **Swift 6 与 C 裸指针安全边界**：
   - C 导出的内部缓冲区裸指针 `const void **buff` 仅在下一次 I/O 前有效。
   - Swift 封装层必须使用 `UnsafeRawBufferPointer` 与 `withUnsafeBytes` 严格限定作用域，严禁裸指针逃逸至并发异步 Task。
3. **强类型错误模型映射**：
   - 将 libarchive 的 6 级错误码 1:1 映射为 Swift 强类型 `TTZipError` 枚举，使 UI 层能清晰区分“单文件跳过”与“归档致命损坏”。
4. **惰性多编码字符串模型**：
   - 借鉴 `struct archive_mstring` 模式，在桥接层对 Windows GBK/Shift-JIS 编码进行惰性转码，避免数万文件遍历时的无谓堆分配。
