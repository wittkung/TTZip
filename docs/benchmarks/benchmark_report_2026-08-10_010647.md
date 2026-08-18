# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-09 17:06:47 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS Version 26.6 (Build 25G72)
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | BZ2 | 1 | 无 | pbzip2 (All Cores) | 0.07 MB (0.6%) | 0.06 MB (0.5%) | 87.8 MB/s | 95.5 MB/s | **1.1x** | 184.3 MB/s | 194.8 MB/s | **1.1x** |
| 海量小文件 (10MB/100文件) | BZ2 | 9 | 无 | pbzip2 (All Cores) | 0.02 MB (0.1%) | 0.01 MB (0.1%) | 50.9 MB/s | 55.2 MB/s | **1.1x** | 111.2 MB/s | 133.7 MB/s | **1.2x** |
| 拟真日志文本 (10MB) | BZ2 | 1 | 无 | pbzip2 (All Cores) | 0.03 MB (0.3%) | 0.03 MB (0.3%) | 98.0 MB/s | 103.8 MB/s | **1.1x** | 213.7 MB/s | 1488.9 MB/s | **7.0x** |
| 拟真日志文本 (10MB) | BZ2 | 9 | 无 | pbzip2 (All Cores) | 0.00 MB (0.1%) | 0.00 MB (0.0%) | 70.0 MB/s | 71.6 MB/s | **1.0x** | 201.9 MB/s | 1240.5 MB/s | **6.1x** |
| 高熵物理Payload (100MB) | BZ2 | 1 | 无 | pbzip2 (All Cores) | 100.82 MB (100.8%) | 100.82 MB (100.8%) | 224.5 MB/s | 234.7 MB/s | **1.0x** | 467.2 MB/s | 2409.0 MB/s | **5.2x** |
| 高熵物理Payload (100MB) | BZ2 | 9 | 无 | pbzip2 (All Cores) | 100.46 MB (100.5%) | 100.46 MB (100.5%) | 200.2 MB/s | 212.6 MB/s | **1.1x** | 302.1 MB/s | 1944.6 MB/s | **6.4x** |
| 500MB 大文件数据块 (500MB) | BZ2 | 1 | 无 | pbzip2 (All Cores) | 0.03 MB (0.0%) | 0.03 MB (0.0%) | 2314.2 MB/s | 2768.7 MB/s | **1.2x** | 1967.8 MB/s | 87650.1 MB/s | **44.5x** |
| 500MB 大文件数据块 (500MB) | BZ2 | 9 | 无 | pbzip2 (All Cores) | 0.03 MB (0.0%) | 0.03 MB (0.0%) | 2340.6 MB/s | 2858.7 MB/s | **1.2x** | 1949.9 MB/s | 86581.3 MB/s | **44.4x** |
