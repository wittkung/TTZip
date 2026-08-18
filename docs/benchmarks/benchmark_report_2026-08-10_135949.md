# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-10 05:59:49 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS Version 26.6 (Build 25G72)
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 拟真日志文本 (10MB) | ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 2127.0 MB/s | 7769.2 MB/s | **3.7x** | 2339.6 MB/s | 7584.8 MB/s | **3.2x** |
| 拟真日志文本 (10MB) | ZST | 9 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1157.4 MB/s | 2199.3 MB/s | **1.9x** | 2107.2 MB/s | 7113.3 MB/s | **3.4x** |
| 高熵物理Payload (100MB) | ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 6206.0 MB/s | 6053.8 MB/s | **1.0x** | 8204.2 MB/s | 7246.7 MB/s | **0.9x** |
| 高熵物理Payload (100MB) | ZST | 9 | 无 | Zstandard zstd (Thread=0) | 1.01 MB (1.0%) | 1.01 MB (1.0%) | 4896.0 MB/s | 6277.2 MB/s | **1.3x** | 8806.7 MB/s | 12087.1 MB/s | **1.4x** |
| 100MB 大文件数据块 (100MB) | ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 9949.9 MB/s | 12069.3 MB/s | **1.2x** | 5639.0 MB/s | 10823.0 MB/s | **1.9x** |
| 100MB 大文件数据块 (100MB) | ZST | 9 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 4280.9 MB/s | 5446.3 MB/s | **1.3x** | 5806.7 MB/s | 13708.9 MB/s | **2.4x** |
