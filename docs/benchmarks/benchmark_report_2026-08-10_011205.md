# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-09 17:12:05 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS Version 26.6 (Build 25G72)
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | XZ | 1 | 无 | pixz (Parallel XZ) | 0.01 MB (0.1%) | 0.01 MB (0.1%) | 253.6 MB/s | 290.1 MB/s | **1.1x** | 256.2 MB/s | 293.1 MB/s | **1.1x** |
| 海量小文件 (10MB/100文件) | XZ | 9 | 无 | pixz (Parallel XZ) | 0.01 MB (0.0%) | 0.01 MB (0.0%) | 104.2 MB/s | 108.9 MB/s | **1.0x** | 227.6 MB/s | 269.2 MB/s | **1.2x** |
| 拟真日志文本 (10MB) | XZ | 1 | 无 | pixz (Parallel XZ) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 528.1 MB/s | 827.5 MB/s | **1.6x** | 699.6 MB/s | 1005.7 MB/s | **1.4x** |
| 拟真日志文本 (10MB) | XZ | 9 | 无 | pixz (Parallel XZ) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 154.8 MB/s | 183.6 MB/s | **1.2x** | 548.8 MB/s | 555.7 MB/s | **1.0x** |
| 高熵物理Payload (100MB) | XZ | 1 | 无 | pixz (Parallel XZ) | 50.03 MB (50.0%) | 50.03 MB (50.0%) | 170.1 MB/s | 183.2 MB/s | **1.1x** | 1688.9 MB/s | 5695.9 MB/s | **3.4x** |
| 高熵物理Payload (100MB) | XZ | 9 | 无 | pixz (Parallel XZ) | 1.02 MB (1.0%) | 1.01 MB (1.0%) | 30.1 MB/s | 38.7 MB/s | **1.3x** | 1105.2 MB/s | 1413.9 MB/s | **1.3x** |
| 500MB 大文件数据块 (500MB) | XZ | 1 | 无 | pixz (Parallel XZ) | 0.10 MB (0.0%) | 0.10 MB (0.0%) | 2001.1 MB/s | 3640.1 MB/s | **1.8x** | 824.0 MB/s | 54419.5 MB/s | **66.0x** |
| 500MB 大文件数据块 (500MB) | XZ | 9 | 无 | pixz (Parallel XZ) | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 343.7 MB/s | 402.1 MB/s | **1.2x** | 490.8 MB/s | 3638.5 MB/s | **7.4x** |
