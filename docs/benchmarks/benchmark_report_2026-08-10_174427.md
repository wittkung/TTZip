# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-10 09:44:27 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 874.6 MB/s | 269.9 MB/s | **0.3x** | 687.2 MB/s | 558.6 MB/s | **0.8x** |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 827.8 MB/s | 284.4 MB/s | **0.3x** | 547.9 MB/s | 421.6 MB/s | **0.8x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 296.6 MB/s | 297.4 MB/s | **1.0x** | 622.2 MB/s | 617.1 MB/s | **1.0x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 290.1 MB/s | 275.2 MB/s | **0.9x** | 489.9 MB/s | 466.5 MB/s | **1.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 450.4 MB/s | 5378.1 MB/s | **11.9x** | 603.6 MB/s | 2029.0 MB/s | **3.4x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 415.5 MB/s | 2173.6 MB/s | **5.2x** | 291.6 MB/s | 1646.2 MB/s | **5.6x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 345.9 MB/s | 5265.3 MB/s | **15.2x** | 564.8 MB/s | 1891.7 MB/s | **3.3x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 336.3 MB/s | 2050.7 MB/s | **6.1x** | 292.3 MB/s | 1996.6 MB/s | **6.8x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.07 MB (0.6%) | 279.4 MB/s | 194.6 MB/s | **0.7x** | 227.9 MB/s | 317.8 MB/s | **1.4x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.07 MB (0.6%) | 287.2 MB/s | 220.6 MB/s | **0.8x** | 237.7 MB/s | 301.2 MB/s | **1.3x** |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 927.5 MB/s | 277.5 MB/s | **0.3x** | 1076.7 MB/s | 812.2 MB/s | **0.8x** |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 769.4 MB/s | 271.7 MB/s | **0.4x** | 711.6 MB/s | 551.1 MB/s | **0.8x** |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 282.4 MB/s | 275.5 MB/s | **1.0x** | 852.2 MB/s | 882.6 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 271.4 MB/s | 269.6 MB/s | **1.0x** | 556.7 MB/s | 560.6 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 601.1 MB/s | 1552.1 MB/s | **2.6x** | 830.8 MB/s | 5171.6 MB/s | **6.2x** |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 569.9 MB/s | 1383.1 MB/s | **2.4x** | 881.7 MB/s | 4418.5 MB/s | **5.0x** |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 79.3 MB/s | 1092.1 MB/s | **13.8x** | 809.9 MB/s | 5968.7 MB/s | **7.4x** |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 80.3 MB/s | 1044.5 MB/s | **13.0x** | 915.3 MB/s | 4852.4 MB/s | **5.3x** |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1387.5 MB/s | 620.8 MB/s | **0.4x** | 1263.0 MB/s | 987.6 MB/s | **0.8x** |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1028.3 MB/s | 703.1 MB/s | **0.7x** | 1265.1 MB/s | 730.2 MB/s | **0.6x** |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.7%) | 0.03 MB (0.3%) | 622.2 MB/s | 451.3 MB/s | **0.7x** | 790.1 MB/s | 1883.9 MB/s | **2.4x** |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 647.9 MB/s | 454.9 MB/s | **0.7x** | 757.2 MB/s | 1752.1 MB/s | **2.3x** |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 182.2 MB/s | 137.4 MB/s | **0.8x** | 3894.9 MB/s | 1358.7 MB/s | **0.3x** |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 192.8 MB/s | 166.6 MB/s | **0.9x** | 2980.4 MB/s | 1408.5 MB/s | **0.5x** |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 132.5 MB/s | 168.4 MB/s | **1.3x** | 1577.2 MB/s | 1578.3 MB/s | **1.0x** |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 131.8 MB/s | 156.1 MB/s | **1.2x** | 1449.5 MB/s | 1302.3 MB/s | **0.9x** |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 81.0 MB/s | 191.7 MB/s | **2.4x** | 3352.7 MB/s | 5547.1 MB/s | **1.7x** |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 81.2 MB/s | 181.4 MB/s | **2.2x** | 1704.0 MB/s | 2173.4 MB/s | **1.3x** |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 72.9 MB/s | 151.5 MB/s | **2.1x** | 3548.8 MB/s | 6963.0 MB/s | **2.0x** |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 68.9 MB/s | 145.4 MB/s | **2.1x** | 1687.7 MB/s | 2163.1 MB/s | **1.3x** |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4771.7 MB/s | 1187.4 MB/s | **0.2x** | 5376.7 MB/s | 1114.4 MB/s | **0.2x** |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 5172.3 MB/s | 1337.4 MB/s | **0.3x** | 5471.3 MB/s | 3633.1 MB/s | **0.7x** |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 880.5 MB/s | 65.1 MB/s | **0.1x** | 1509.7 MB/s | 3726.2 MB/s | **2.5x** |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 705.8 MB/s | 54.9 MB/s | **0.1x** | 1104.0 MB/s | 2334.8 MB/s | **2.1x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5023.3 MB/s | 623.1 MB/s | **0.1x** | 5115.4 MB/s | 3153.5 MB/s | **0.6x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4960.4 MB/s | 615.0 MB/s | **0.1x** | 4719.7 MB/s | 3202.2 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 657.8 MB/s | 618.3 MB/s | **0.9x** | 3566.5 MB/s | 3405.7 MB/s | **1.0x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 655.0 MB/s | 624.9 MB/s | **1.0x** | 3356.9 MB/s | 3121.3 MB/s | **0.9x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1012.3 MB/s | 1601.3 MB/s | **1.6x** | 1710.0 MB/s | 6081.9 MB/s | **3.6x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1009.4 MB/s | 1569.2 MB/s | **1.6x** | 2013.6 MB/s | 6832.2 MB/s | **3.4x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.3 MB/s | 1136.4 MB/s | **12.2x** | 1658.8 MB/s | 11138.1 MB/s | **6.7x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 91.6 MB/s | 1018.3 MB/s | **11.1x** | 1951.2 MB/s | 5466.8 MB/s | **2.8x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 13731.5 MB/s | 1622.3 MB/s | **0.1x** | 5586.9 MB/s | 4993.7 MB/s | **0.9x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10516.0 MB/s | 1233.8 MB/s | **0.1x** | 6317.7 MB/s | 5700.3 MB/s | **0.9x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 1779.1 MB/s | 594.8 MB/s | **0.3x** | 1326.5 MB/s | 3067.0 MB/s | **2.3x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 2008.6 MB/s | 580.5 MB/s | **0.3x** | 1688.0 MB/s | 2894.1 MB/s | **1.7x** |
