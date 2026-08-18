# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 04:52:11 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 915.1 MB/s | 576.5 MB/s | **0.6x** | 747.4 MB/s | 692.1 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 872.8 MB/s | 568.0 MB/s | **0.7x** | 570.3 MB/s | 531.0 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 289.3 MB/s | 242.4 MB/s | **0.8x** | 639.4 MB/s | 597.7 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 284.6 MB/s | 238.8 MB/s | **0.8x** | 493.9 MB/s | 456.6 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 432.5 MB/s | 1268.5 MB/s | **2.9x** | 592.7 MB/s | 2002.5 MB/s | **3.4x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 413.2 MB/s | 889.8 MB/s | **2.2x** | 307.7 MB/s | 1992.8 MB/s | **6.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 355.2 MB/s | 1234.8 MB/s | **3.5x** | 602.0 MB/s | 1728.2 MB/s | **2.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 337.4 MB/s | 936.2 MB/s | **2.8x** | 266.2 MB/s | 1868.6 MB/s | **7.0x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 279.8 MB/s | 1042.1 MB/s | **3.7x** | 289.0 MB/s | 1089.7 MB/s | **3.8x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 287.2 MB/s | 1021.8 MB/s | **3.6x** | 291.7 MB/s | 985.7 MB/s | **3.4x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1089.7 MB/s | 933.3 MB/s | **0.9x** | 1388.4 MB/s | 1190.7 MB/s | **0.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 951.5 MB/s | 912.3 MB/s | **1.0x** | 853.2 MB/s | 835.7 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 294.0 MB/s | 286.9 MB/s | **1.0x** | 994.4 MB/s | 980.5 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 290.2 MB/s | 284.8 MB/s | **1.0x** | 693.8 MB/s | 673.7 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 667.6 MB/s | 1776.5 MB/s | **2.7x** | 945.8 MB/s | 4658.6 MB/s | **4.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 661.1 MB/s | 1630.0 MB/s | **2.5x** | 1086.3 MB/s | 4700.0 MB/s | **4.3x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 78.4 MB/s | 1267.2 MB/s | **16.2x** | 973.0 MB/s | 6620.3 MB/s | **6.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 79.2 MB/s | 1203.7 MB/s | **15.2x** | 1054.9 MB/s | 4977.3 MB/s | **4.7x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1663.7 MB/s | 4156.2 MB/s | **2.5x** | 1672.7 MB/s | 4312.5 MB/s | **2.6x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1312.4 MB/s | 4306.2 MB/s | **3.3x** | 1606.1 MB/s | 4719.5 MB/s | **2.9x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 791.4 MB/s | 4360.4 MB/s | **5.5x** | 969.5 MB/s | 5595.9 MB/s | **5.8x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 812.4 MB/s | 4570.8 MB/s | **5.6x** | 933.3 MB/s | 5769.0 MB/s | **6.2x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.01 MB (100.0%) | 221.9 MB/s | 231.2 MB/s | **1.0x** | 4243.0 MB/s | 4097.4 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.01 MB (100.0%) | 230.6 MB/s | 227.2 MB/s | **1.0x** | 3382.6 MB/s | 3327.4 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 148.7 MB/s | 146.7 MB/s | **1.0x** | 1704.3 MB/s | 1673.4 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 145.1 MB/s | 145.7 MB/s | **1.0x** | 1467.8 MB/s | 1525.6 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 87.9 MB/s | 181.3 MB/s | **2.1x** | 3874.4 MB/s | 11191.6 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 82.1 MB/s | 172.4 MB/s | **2.1x** | 1923.6 MB/s | 2359.5 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 74.7 MB/s | 148.4 MB/s | **2.0x** | 3811.5 MB/s | 10993.1 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 72.1 MB/s | 139.2 MB/s | **1.9x** | 1946.8 MB/s | 2408.2 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 10.09 MB (10.1%) | 5366.1 MB/s | 8576.1 MB/s | **1.6x** | 5902.4 MB/s | 6670.4 MB/s | **1.1x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 10.09 MB (10.1%) | 5874.1 MB/s | 8738.8 MB/s | **1.5x** | 7376.4 MB/s | 6787.1 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 1040.8 MB/s | 1784.0 MB/s | **1.7x** | 1673.6 MB/s | 5139.6 MB/s | **3.1x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 1001.4 MB/s | 1801.4 MB/s | **1.8x** | 1676.4 MB/s | 5623.2 MB/s | **3.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.11 MB (0.0%) | 5551.5 MB/s | 5583.1 MB/s | **1.0x** | 5803.1 MB/s | 5846.2 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.11 MB (0.0%) | 5627.5 MB/s | 4964.9 MB/s | **0.9x** | 5281.3 MB/s | 4818.9 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 686.3 MB/s | 679.7 MB/s | **1.0x** | 3804.7 MB/s | 3803.7 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 680.4 MB/s | 687.2 MB/s | **1.0x** | 3638.7 MB/s | 3558.7 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1044.9 MB/s | 1866.2 MB/s | **1.8x** | 1783.6 MB/s | 6945.3 MB/s | **3.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1044.4 MB/s | 1874.9 MB/s | **1.8x** | 2132.7 MB/s | 7570.3 MB/s | **3.5x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 97.3 MB/s | 1267.4 MB/s | **13.0x** | 1610.2 MB/s | 12111.3 MB/s | **7.5x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 98.1 MB/s | 1239.4 MB/s | **12.6x** | 2137.8 MB/s | 11736.2 MB/s | **5.5x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 15083.5 MB/s | 12757.9 MB/s | **0.8x** | 5960.4 MB/s | 6487.9 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10457.9 MB/s | 14856.4 MB/s | **1.4x** | 6404.9 MB/s | 6985.2 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2182.5 MB/s | 9683.4 MB/s | **4.4x** | 1970.7 MB/s | 3320.5 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2032.2 MB/s | 9171.8 MB/s | **4.5x** | 1973.6 MB/s | 3329.4 MB/s | **1.7x** | - |
