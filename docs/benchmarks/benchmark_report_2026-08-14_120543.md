# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 04:05:43 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 445.8 MB/s | 1243.9 MB/s | **2.8x** | 525.2 MB/s | 1604.0 MB/s | **3.1x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 423.2 MB/s | 901.2 MB/s | **2.1x** | 307.7 MB/s | 1711.8 MB/s | **5.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 365.7 MB/s | 1286.2 MB/s | **3.5x** | 578.9 MB/s | 2043.6 MB/s | **3.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 347.9 MB/s | 946.6 MB/s | **2.7x** | 297.9 MB/s | 1592.6 MB/s | **5.3x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 671.5 MB/s | 1742.7 MB/s | **2.6x** | 987.2 MB/s | 4730.1 MB/s | **4.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 663.4 MB/s | 1631.8 MB/s | **2.5x** | 1064.8 MB/s | 4645.5 MB/s | **4.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 80.1 MB/s | 1297.0 MB/s | **16.2x** | 961.8 MB/s | 6664.8 MB/s | **6.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 79.7 MB/s | 1194.8 MB/s | **15.0x** | 1043.6 MB/s | 4665.4 MB/s | **4.5x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 91.6 MB/s | 191.7 MB/s | **2.1x** | 3659.8 MB/s | 9560.7 MB/s | **2.6x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 82.8 MB/s | 180.3 MB/s | **2.2x** | 1711.9 MB/s | 2356.2 MB/s | **1.4x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 73.6 MB/s | 148.6 MB/s | **2.0x** | 2542.5 MB/s | 10420.6 MB/s | **4.1x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 73.7 MB/s | 129.4 MB/s | **1.8x** | 1798.2 MB/s | 2354.3 MB/s | **1.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1053.4 MB/s | 1113.6 MB/s | **1.1x** | 1768.8 MB/s | 6805.8 MB/s | **3.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1052.4 MB/s | 1912.2 MB/s | **1.8x** | 2156.4 MB/s | 6741.0 MB/s | **3.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 97.6 MB/s | 1294.2 MB/s | **13.3x** | 1748.2 MB/s | 11430.3 MB/s | **6.5x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 99.3 MB/s | 1309.0 MB/s | **13.2x** | 2119.3 MB/s | 10796.8 MB/s | **5.1x** | - |
