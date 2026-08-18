# Google Zopfli 深度算法架构解析与开源上游优化研究报告

**文档状态**: COMPLETE (Feature 105 交付工件)  
**作者**: Antigravity / CTO Lead  
**日期**: 2026-08-19  
**代码库基准**: `Vendor/zopfli-upstream/` (`git@github.com:google/zopfli.git`)  

---

## 1. 架构总览 (Architectural Overview)

Google Zopfli 是一款以极限无损空间节省率为目标的 DEFLATE/zlib/gzip 压缩算法库。其核心设计哲学是：**完全解耦压缩耗时与解压兼容性**——在压缩侧利用图论最短路径、香农自信息开销建模和多轮迭代松弛穷举最优匹配序列，产出严格符合 RFC 1951 规范的比特流，使任何标准解压器（`/usr/bin/unzip`、`libdeflate` 等）均能以零开销极速解压。

```
[原始输入字节流]
       │
       ▼
 ┌─────────────────────────────────────────────────────────────┐
 │ 1. 动态局部熵变分块 (Dynamic Block Splitter via Entropy)     │
 │    - 9点网格二分搜索 (`FindMinimum` + `SplitCost`)           │
 └──────────────────────────────┬──────────────────────────────┘
                                │
                                ▼
 ┌─────────────────────────────────────────────────────────────┐
 │ 2. LZ77 最优匹配解析器 (Optimal Match Parsing / Squeeze)    │
 │    - 有向无环图 (DAG) 前向最短路径 DP (`GetBestLengths`)      │
 │    - 哈希链滑动窗口与最长匹配查找 (`ZopfliFindLongestMatch`) │
 └──────────────────────────────┬──────────────────────────────┘
                                │
                                ▼
 ┌─────────────────────────────────────────────────────────────┐
 │ 3. 多轮统计重加权迭代 (Iterative Re-weighting Loop)         │
 │    - 香农自信息开销估计 (`GetCostStat`)                     │
 │    - Marsaglia PRNG 局部极小退火扰动与加权动量平滑          │
 └──────────────────────────────┬──────────────────────────────┘
                                │
                                ▼
 ┌─────────────────────────────────────────────────────────────┐
 │ 4. Katajainen 边界包合并算法 (15-bit Length-Limited Codes)   │
 │    - $O(L \cdot N)$ 时间与静态内存池生成最优受限 Huffman 树   │
 └──────────────────────────────┬──────────────────────────────┘
                                │
                                ▼
 ┌─────────────────────────────────────────────────────────────┐
 │ 5. 18 核心分块多线程并发编排 (18-Core Multi-Block Parallel)  │
 │    - 32KB 跨 Tile 历史字典预热 (`ZopfliWarmupHash`)         │
 │    - RFC 1951 `Z_SYNC_FLUSH` 字节对齐拼接                   │
 └─────────────────────────────────────────────────────────────┘
```

---

## 2. 五大核心算法机制深度剖析

### 2.1 最优路径图论 DP (`squeeze.c`)
- **图论建模**：字节偏移为 DAG 节点 $j \in [0, N]$。字面量构成权为 $\text{Cost}_{\text{lit}}$ 的长度 1 边；历史匹配构成权为 $\text{Cost}_{\text{match}}(k, d)$ 的长度 $k \in [3, 258]$ 边。
- **前向松弛**：
  $$\text{costs}[j + k] = \min(\text{costs}[j + k], \text{costs}[j] + \text{Cost}(k, d))$$
- **剪枝优化**：预先提取模型最小边权 $\text{mincost}$，若当前累计代价已超阈值，短路跳过后续昂贵计算。

### 2.2 香农自信息与迭代重加权 (`squeeze.c` / `tree.c`)
- **开销模型**：
  $$L_i = -\log_2(P_i) = \frac{\ln(\sum C) - \ln(C_i)}{\ln 2}$$
- **打破循环博弈**：初始由 Greedy 粗解提供先验概率，在 5~15 轮 Squeeze 中持续用最优路径生成的频数反馈修正开销函数，逼近全局香农熵极限。
- **动量平滑**：引入 $C_{\text{new}} = 1.0 \times C^{(t)} + 0.5 \times C^{(t-1)}$ 消除频数振荡。

### 2.3 Katajainen 边界包合并算法 (`katajainen.c`)
- 传统 Huffman 堆合并在极偏态分布下会产生深度 $> 15$ 的非法码树。
- Katajainen Package-Merge 算法在 $O(L \cdot N)$ 时间复杂度内直接析取满足 $\le 15\text{ bit}$ 约束的全局最优码长数组，预分配静态 `NodePool`，热路径零堆碎片。

### 2.4 动态局部熵变块切分 (`blocksplitter.c`)
- 采用 9 点采样网格与二分搜索（`FindMinimum`），以动态 Huffman 树描述符与数据比特和为代价函数，精确发现局部熵突变边界。

### 2.5 TTZip 18 核心并发与 32KB 历史字典预热 (`ttzip_zopfli_engine.c`)
- 100MB 大文件均匀划分为 18 个 Tile，非首块 Tile 传入前一 Tile 末尾 32KB 字节，调用 `ZopfliWarmupHash` 预热哈希链，使跨块匹配无损保留。
- 采用 RFC 1951 空非压缩块追加 `Z_SYNC_FLUSH`（`0x00, 0x00, 0xFF, 0xFF`），各线程结果字节对齐，主线程极速内存拼接。

---

## 3. 开源上游 (Google Zopfli Upstream) 优化潜力分析

经过对 `Vendor/zopfli-upstream/src/zopfli/` 的源码审计，识别出以下 3 项高价值 Upstream PR 优化方向：

| 优化方向 | 涉及文件 | 潜在收益 | 技术方案 |
| :--- | :--- | :--- | :--- |
| **1. ARM64 NEON SWAR 匹配查找向量化** | `lz77.c` (`ZopfliFindLongestMatch`) | 匹配查找吞吐提升 25%~40% | 使用 ARM64 `vld1q_u8` 与 `cmeq` 一次性比对 16 字节字符，替代逐字节标量比较 |
| **2. Log2 浮点计算整型查表化** | `tree.c` (`ZopfliCalculateEntropy`) | 熵计算耗时降低 50% | 引入 Q8.8 定点数尾数查表 `s_log2_mantissa_lut`，消除 `log()` 软浮点系统调用 |
| **3. macOS CMake / Makefile 链接参数跨平台修复** | `Makefile` (`libzopfli`) | 消除 macOS 编译红灯 | 将 Linux `-Wl,-soname,libzopfli.so.1` 适配为 macOS `-dynamiclib -Wl,-install_name` |
