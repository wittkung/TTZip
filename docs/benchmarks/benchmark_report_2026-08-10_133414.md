# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-10 05:34:14 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS Version 26.6 (Build 25G72)
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.05 MB (0.4%) | 253.4 MB/s | 3307.5 MB/s | **13.1x** | 272.0 MB/s | 1413.0 MB/s | **5.2x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 9 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 266.3 MB/s | 2966.1 MB/s | **11.1x** | 281.3 MB/s | 1496.2 MB/s | **5.3x** |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.7%) | 0.04 MB (0.4%) | 673.6 MB/s | 5572.1 MB/s | **8.3x** | 815.5 MB/s | 7346.3 MB/s | **9.0x** |
| 拟真日志文本 (10MB) | TAR.GZ | 9 | 无 | Parallel pigz (All Cores) | 0.03 MB (0.4%) | 0.04 MB (0.4%) | 669.7 MB/s | 5263.0 MB/s | **7.9x** | 873.3 MB/s | 7623.2 MB/s | **8.7x** |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.02 MB (100.0%) | 466.6 MB/s | 2209.1 MB/s | **4.7x** | 972.8 MB/s | 5756.7 MB/s | **5.9x** |
| 高熵物理Payload (100MB) | TAR.GZ | 9 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.02 MB (100.0%) | 437.3 MB/s | 1700.1 MB/s | **3.9x** | 683.0 MB/s | 6431.3 MB/s | **9.4x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.61 MB (0.1%) | 2228.4 MB/s | 8706.8 MB/s | **3.9x** | 1941.2 MB/s | 4261.9 MB/s | **2.2x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 9 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.53 MB (0.1%) | 2045.2 MB/s | 8583.5 MB/s | **4.2x** | 2003.6 MB/s | 4538.2 MB/s | **2.3x** |
