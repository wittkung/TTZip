# 理解 CRC32：从代数数学原理到 libarchive 的 ARMv8 硬件加速实现

> **作者**：Kevin Tung (@wittkung)  
> **代码参考**：[libarchive PR #3391](https://github.com/libarchive/libarchive/pull/3391) (已合并至主干，Commit: `8e439b92`)

---

## 引言

这是我第一次尝试给 `libarchive` 这样历史悠久的开源基础库提交 Pull Request。前几天看到它被项目创始人正式 Merge 合入主干的那一刻，内心还是非常开心的。

前段时间在开发面向 macOS 的高性能原生归档工具 [**TTZip**](https://github.com/wittkung/TTZip) 时，我注意到 `libarchive` 中的 CRC32 校验在 ARM64 架构下主要还是基于传统的软件查表实现。借助现代 ARMv8 架构提供的 ACLE 硬件单周期指令，其实可以把这部分计算大幅提速。

于是我花了一些时间，把底层的代数数学原理彻底理了一遍，写了硬件加速实现并提交了 PR。在几轮审查和修改中，我也踩了几个之前在本地单机开发时完全没注意到的跨平台工程细节，收获很大。

借着这次合并的机会，我把这些关于 **CRC32 的底层数学原理**、**从查表到硬件指令的演进**，以及**初次给顶级开源项目提 PR 的真实踩坑体会**系统地整理成这篇笔记，希望能给对底层原理或开源协作感兴趣的朋友提供一点参考。

---

## 一、 基础背景：libarchive 是什么？

在 Unix 和类 Unix 系统中，文件的“打包”与“压缩”通常是解耦的两层操作：

- **归档（Archiving）**：把多个文件、目录、权限信息组装成一个连续的数据流（例如 `.tar` 或 `.cpio`），本身不改变数据体积；
- **压缩（Compression）**：通过算法（如 Deflate、Zstd、LZMA）去除数据中的冗余，减小体积（例如 `.gz`、`.zst`、`.xz`）。

`libarchive` 是一个开源的 C 语言基础库，提供了流式读取和写入各种归档格式（TAR、CPIO、ZIP、7-Zip、ISO 等）的通用接口。macOS 系统自带的 `bsdtar`、FreeBSD 的系统安装器以及很多 Linux 发行版的包管理工具，底层都在使用它来处理各类压缩与归档文件。

在几乎所有的归档格式中，为了防止数据在存储或传输过程中损坏，都会附带一个 32 位的校验码，这就是 CRC32。

---

## 二、 为什么需要 CRC 校验？

在磁盘读写或网络传输过程中，偶尔会出现某一个比特从 `0` 变成 `1`（即比特翻转）。如果解压软件不能发现这种微小损坏，解压出来的文件就会出错。

### 为什么简单的加法 Checksum 不够用？

最朴素的校验想法是把所有字节相加求和（即 Checksum）：

$$\text{Checksum} = \sum \text{byte}_i \pmod{256}$$

但简单的加法有明显的局限性：
1. **无法识别位置调换**：如果数据中的 `A` 和 `B` 发生了顺序颠倒，它们的总和完全不变；
2. **增减相互抵消**：如果一个字节加了 1，另一个字节减了 1，累加和依然不变；
3. **无法感知连续的零**：在开头或末尾插入多个 `0x00`，累加和不受影响。

CRC（Cyclic Redundancy Check，循环冗余校验）正是为了解决这些问题而设计的。它利用多项式除法，对数据的排列顺序和突发错误具有极高的敏感性。

---

## 三、 CRC32 的数学原理：有限域 $GF(2)$ 上的多项式长除法

CRC 的数学基础并不复杂，核心就是**多项式除法**，但它定义在一个特殊的数域上——**二元有限域 $GF(2)$**。

### 3.1 把二进制看作多项式

在 $GF(2)$ 中，一串二进制数据可以直接看作一个系数只能是 `0` 或 `1` 的多项式。

例如，字节 `10011` 可以写成：
$$M(x) = 1\cdot x^4 + 0\cdot x^3 + 0\cdot x^2 + 1\cdot x^1 + 1\cdot x^0 = x^4 + x + 1$$

数据的每一位（bit）就是多项式每一项前面的系数。

### 3.2 $GF(2)$ 的运算规则：加减法就是异或（XOR）

在 $GF(2)$ 域中，加法和减法都不考虑进位和借位（模 2 运算）：
- $0 + 0 = 0,\quad 0 + 1 = 1,\quad 1 + 0 = 1,\quad 1 + 1 = 0$
- $0 - 0 = 0,\quad 1 - 0 = 1,\quad 0 - 1 = 1,\quad 1 - 1 = 0$

可以看到，加法和减法的规则完全一样，在计算机中对应的就是按位异或操作（$\oplus$）。

### 3.3 CRC 的计算过程：多项式求余数

CRC 的计算其实就是小学学过的**多项式长除法**：

1. 选定一个固定的**生成多项式** $G(x)$（CRC32 的最高次幂为 32）；
2. 将待校验的数据 $M(x)$ 乘以 $x^{32}$（相当于在数据后面补 32 个 0）；
3. 用补零后的数据除以 $G(x)$，得到的**余数 $R(x)$** 就是 32 位的 CRC 校验值：

$$M(x) \cdot x^{32} = Q(x) \cdot G(x) \oplus R(x)$$

余数 $R(x)$ 的最高次幂一定小于 32，刚好可以存入一个 32 位整数（`uint32_t`）中。

### 3.4 标准多项式与常数 0xEDB88320 的来源

在 IEEE 802.3（以太网、ZIP、PNG、GZIP 广泛采用）标准中，CRC32 的生成多项式为：

$$G(x) = x^{32} + x^{26} + x^{23} + x^{22} + x^{16} + x^{12} + x^{11} + x^{10} + x^8 + x^7 + x^5 + x^4 + x^2 + x + 1$$

写成 33 位二进制是：`1 0000 0100 1100 0001 0001 1101 1011 0111`（十六进制 `0x104C11DB7`）。

在实际软件实现中，由于很多数据格式是低位先传输（LSB-first），为了方便处理，通常会采用**反向多项式（Reflected Polynomial）**：将除去最高位的 32 位二进制按位翻转（Bit-Reverse），就得到了代码中常见的常数：

$$\text{Bit-Reverse}(0x04C11DB7) = \mathbf{0xEDB88320}$$

---

## 四、 CRC32 计算方式的三种实现

在软件工程中，计算 CRC32 主要经历了三种实现方式：

### 4.1 逐比特模拟（最直观但速度较慢）

最基础的做法是直接用代码模拟移位和异或过程，每处理 1 个 bit 循环一次：

```c
uint32_t crc32_bitwise(uint32_t crc, const uint8_t *buf, size_t len) {
    crc = ~crc;
    for (size_t i = 0; i < len; ++i) {
        crc ^= buf[i];
        for (int b = 0; b < 8; ++b) {
            if (crc & 1)
                crc = (crc >> 1) ^ 0xEDB88320;
            else
                crc = crc >> 1;
        }
    }
    return ~crc;
}
```
这种方法分支判断多、步长小，吞吐通常只有每秒几十兆字节。

### 4.2 256 项查表法（经典的以空间换时间）

由于 1 个字节只有 256 种可能（$0\sim 255$），我们可以把每个字节可能产生的余数预先计算出来，存成一张 256 大小的数组（耗费 1 KB 内存）：

```c
static const uint32_t crc32_table[256] = { /* 预先算好的 256 个常量 */ };

uint32_t crc32_table_driven(uint32_t crc, const uint8_t *p, size_t len) {
    crc = ~crc;
    while (len--) {
        crc = (crc >> 8) ^ crc32_table[(crc ^ *p++) & 0xFF];
    }
    return ~crc;
}
```
这是过去几十年来绝大多数标准库（包括 zlib 纯 C 路径）的通用做法，每处理 1 个字节需要一次数组查找与异或。

### 4.3 ARMv8 ACLE 硬件指令（芯片内置硬件计算）

在现代 ARM64 处理器中（如 Apple Silicon 以及各类 ARMv8/v9 芯片），ARM 官方提供了专门的硬件 CRC 指令集（ACLE）：
- `__crc32b`（8 位 / 1 字节）
- `__crc32h`（16 位 / 2 字节）
- `__crc32w`（32 位 / 4 字节）
- `__crc32d`（64 位 / 8 字节宽字）

这些指令由芯片内部的硬件异或门电路直接在一个时钟周期内完成运算。如果以 8 字节（64 位）为步长循环处理，计算速度可以达到每秒数千兆甚至更高，几乎不再构成 CPU 瓶颈。

---

## 五、 在 libarchive 中的重构实现

在梳理 `libarchive` 源码时，可以发现其内部多个格式解析器（如 7-Zip、GZIP、RAR 等）各自保留了分散的私有 CRC 计算宏或局部实现。

为了让整个库统一享受到硬件加速，并且保证在没有硬件支持的平台上能安全回退，本次重构设计了**三级自适应结构**：

```
                    ┌───────────────────────────────┐
                    │     __archive_crc32(...)      │
                    └──────────────┬────────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              ▼                    ▼                    ▼
     【Tier 1: ARMv8 硬件】    【Tier 2: zlib 优化】    【Tier 3: 纯 C 查表】
     使用 ACLE __crc32d 宽字   若系统安装了 zlib 则直通   无任何外部依赖的 256 项
     单周期指令处理大块数据    其内置的汇编优化实现      静态表实现，保证通用兼容
```

### 核心实现代码

```c
#if (defined(__aarch64__) || defined(_M_ARM64)) && !defined(__ARM_BIG_ENDIAN) && !defined(__AARCH64EB__)
#if defined(__ARM_FEATURE_CRC32)
#include <arm_acle.h>

/* Implementation 1: Hardware-accelerated CRC32 using ARMv8 ACLE */
static uint32_t
crc32_armv8(uint32_t crc, const void *buf, size_t len)
{
	const uint8_t *p = (const uint8_t *)buf;
	crc = ~crc;

	/* 64 位宽字步长循环处理 */
	while (len >= 8) {
		uint64_t v;
		memcpy(&v, p, sizeof(v)); /* 遵循严格别名规则，编译器会自动优化为 ldr 指令 */
		crc = __crc32d(crc, v);
		p += 8;
		len -= 8;
	}

	/* 尾部残差阶梯处理：4 字节 -> 2 字节 -> 1 字节 */
	if (len >= 4) {
		uint32_t v;
		memcpy(&v, p, sizeof(v));
		crc = __crc32w(crc, v);
		p += 4;
		len -= 4;
	}
	if (len >= 2) {
		uint16_t v;
		memcpy(&v, p, sizeof(v));
		crc = __crc32h(crc, v);
		p += 2;
		len -= 2;
	}
	if (len > 0) {
		crc = __crc32b(crc, *p);
	}

	return ~crc;
}
#endif
#endif
```

> **注**：在 64 位宽字读取时使用 `memcpy(&v, p, sizeof(v))` 是现代 C 语言的通用做法。它既不会产生未对齐指针访问（UB），现代编译器（Clang/GCC）又会将其直接优化为单条寄存器加载指令，保证了跨平台安全性与零额外开销。

---

## 六、 提交上游过程中的跨平台工程细节

在自己的开发机（macOS / CMake）上写完代码并通过本地测试后，我向上游提交了 PR。在与维护者 Tim Kientzle 的几轮 review 互动中，暴露出了几个平时只用单一构建工具时容易忽略的细节：

### 1. 双构建系统同步与 `Makefile.am` 字母序

`libarchive` 同时维护着 CMake 和传统的 GNU Autotools 两套构建体系：
- 如果只在 `CMakeLists.txt` 中添加了新建的 `archive_crc32.c`，在 CMake 下运行完全正常；
- 但在 Autotools（`./configure && make`）下构建动态库 `libarchive.la` 时，就会因为缺少该源文件而报链接错误（`Undefined symbols`）。

此外，`libarchive` 的 `Makefile.am` 对源文件列表有着严格的 **ASCII 字母序** 规范，新增文件必须精确插入到正确的位置。

### 2. FreeBSD 严格模式下的原型声明要求

在 FreeBSD CI 编译时，开启了 `-Wmissing-prototypes -Werror` 选项，导致编译报错：

```text
archive_crc32.c:98:1: error: no previous prototype for function '__archive_crc32' [-Wmissing-prototypes]
```

在严格的 C 语言规范中，如果一个 `.c` 文件实现了一个全局（非 `static`）函数，该文件自身必须在顶部 `#include` 声明了该函数原型的内部私有头文件（即 `#include "archive_private.h"`）。这样可以让编译器在编译该实现单元时，强制校验原型与实现的签名是否完全一致。

### 3. 条件编译注释的排版风格

在组织 `#if` / `#elif` / `#else` 多分支条件编译时，我最初习惯将说明注释写在宏指令的前面：

```c
/* 不符合代码库传统的排版 */
/* Implementation 1: Hardware-accelerated */
#if defined(__aarch64__)
...
```

维护者指出，在 BSD 传统排版规范中，说明注释属于预处理块的内部上下文，应该写在预处理指令之后：

```c
/* 符合规范的排版 */
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

## 七、 总结与体会

经过几轮针对构建配置与格式规范的调整，并拆分为清晰的 4 个独立原子提交（`infra` $\rightarrow$ `refactor` $\rightarrow$ `feat` $\rightarrow$ `test`）后，PR #3391 顺利通过了所有平台的 CI 测试并合入主干。

回顾这次实践，有几点体会：
1. **理解底层数学能够让代码写得更踏实**：从 $GF(2)$ 多项式除法理解 CRC，能更清楚地明白为什么硬件指令会这样设计，以及各个常数的由来；
2. **多平台工程不能依赖单一环境**：在本地开发时，主动开启严格警告（如 `-Wmissing-prototypes -Wall -Wextra`）并兼顾双构建系统，能省去很多后续沟通成本；
3. **开源社区协作的规范性**：开源项目的维护者不仅关注代码逻辑是否正确，更关注代码的可移植性、回退机制、Commit 历史的整洁度以及代码风格的一致性。

希望这篇关于 CRC32 数学原理与底层实现的梳理，能对从事系统级开发或对底层技术感兴趣的朋友有所帮助。

---

### 相关链接与参考
- **libarchive 官方 PR**：[libarchive/libarchive#3391](https://github.com/libarchive/libarchive/pull/3391)
- **合入 Commit**：[`8e439b92787c8104e22c5958caf0a7ef9532567f`](https://github.com/libarchive/libarchive/commit/8e439b92787c8104e22c5958caf0a7ef9532567f)
- **原生归档项目**：[TTZip (GitHub)](https://github.com/wittkung/TTZip)

