# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-10 11:29:48 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 845.8 MB/s | 289.9 MB/s | **0.3x** | 682.0 MB/s | 605.0 MB/s | **0.9x** |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 816.6 MB/s | 275.5 MB/s | **0.3x** | 519.1 MB/s | 451.6 MB/s | **0.9x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 291.2 MB/s | 286.4 MB/s | **1.0x** | 593.2 MB/s | 516.1 MB/s | **0.9x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 291.0 MB/s | 291.7 MB/s | **1.0x** | 455.4 MB/s | 461.0 MB/s | **1.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 418.1 MB/s | 6100.0 MB/s | **14.6x** | 576.0 MB/s | 2141.2 MB/s | **3.7x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 401.1 MB/s | 2305.3 MB/s | **5.7x** | 288.6 MB/s | 1913.0 MB/s | **6.6x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 243.8 MB/s | 4321.8 MB/s | **17.7x** | 477.0 MB/s | 1979.6 MB/s | **4.2x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 259.8 MB/s | 1203.5 MB/s | **4.6x** | 280.3 MB/s | 1016.9 MB/s | **3.6x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.07 MB (0.6%) | 271.2 MB/s | 218.1 MB/s | **0.8x** | 253.2 MB/s | 300.6 MB/s | **1.2x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.07 MB (0.6%) | 282.6 MB/s | 209.7 MB/s | **0.7x** | 258.0 MB/s | 334.2 MB/s | **1.3x** |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 909.5 MB/s | 278.9 MB/s | **0.3x** | 1169.2 MB/s | 856.6 MB/s | **0.7x** |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 779.8 MB/s | 284.4 MB/s | **0.4x** | 710.3 MB/s | 573.4 MB/s | **0.8x** |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 287.9 MB/s | 286.1 MB/s | **1.0x** | 882.5 MB/s | 859.8 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 279.0 MB/s | 277.7 MB/s | **1.0x** | 569.6 MB/s | 560.6 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 617.0 MB/s | 1540.1 MB/s | **2.5x** | 861.7 MB/s | 5935.9 MB/s | **6.9x** |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 582.1 MB/s | 1411.0 MB/s | **2.4x** | 884.7 MB/s | 4140.5 MB/s | **4.7x** |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 80.0 MB/s | 1159.4 MB/s | **14.5x** | 834.6 MB/s | 6918.9 MB/s | **8.3x** |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 80.9 MB/s | 1098.5 MB/s | **13.6x** | 890.5 MB/s | 4887.7 MB/s | **5.5x** |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1343.1 MB/s | 934.6 MB/s | **0.7x** | 1315.6 MB/s | 1120.5 MB/s | **0.9x** |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1048.4 MB/s | 849.7 MB/s | **0.8x** | 1279.4 MB/s | 1170.3 MB/s | **0.9x** |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.7%) | 0.03 MB (0.3%) | 653.2 MB/s | 467.9 MB/s | **0.7x** | 809.5 MB/s | 2065.6 MB/s | **2.6x** |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 645.3 MB/s | 461.3 MB/s | **0.7x** | 800.0 MB/s | 1967.8 MB/s | **2.5x** |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 209.1 MB/s | 127.1 MB/s | **0.6x** | 3871.9 MB/s | 1366.0 MB/s | **0.4x** |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 182.7 MB/s | 177.3 MB/s | **1.0x** | 2947.6 MB/s | 1458.0 MB/s | **0.5x** |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 143.6 MB/s | 135.4 MB/s | **0.9x** | 1601.1 MB/s | 1461.5 MB/s | **0.9x** |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 142.5 MB/s | 170.4 MB/s | **1.2x** | 1467.4 MB/s | 1435.9 MB/s | **1.0x** |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 87.1 MB/s | 197.5 MB/s | **2.3x** | 3497.6 MB/s | 8447.9 MB/s | **2.4x** |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 80.5 MB/s | 171.0 MB/s | **2.1x** | 1700.0 MB/s | 2156.2 MB/s | **1.3x** |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 72.8 MB/s | 156.0 MB/s | **2.1x** | 3444.6 MB/s | 9050.5 MB/s | **2.6x** |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.0 MB/s | 132.9 MB/s | **1.9x** | 1684.2 MB/s | 2146.3 MB/s | **1.3x** |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4684.6 MB/s | 1325.8 MB/s | **0.3x** | 6706.8 MB/s | 1620.9 MB/s | **0.2x** |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 4438.8 MB/s | 989.3 MB/s | **0.2x** | 5024.5 MB/s | 2457.9 MB/s | **0.5x** |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 659.5 MB/s | 37.4 MB/s | **0.1x** | 458.5 MB/s | 2918.9 MB/s | **6.4x** |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 605.4 MB/s | 60.9 MB/s | **0.1x** | 1047.8 MB/s | 3015.4 MB/s | **2.9x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5191.2 MB/s | 583.0 MB/s | **0.1x** | 4948.3 MB/s | 3274.9 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5343.7 MB/s | 612.1 MB/s | **0.1x** | 5157.8 MB/s | 3495.3 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 655.4 MB/s | 647.6 MB/s | **1.0x** | 3757.9 MB/s | 3762.1 MB/s | **1.0x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 659.9 MB/s | 643.8 MB/s | **1.0x** | 3570.9 MB/s | 3583.3 MB/s | **1.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1025.9 MB/s | 1633.0 MB/s | **1.6x** | 1714.4 MB/s | 6101.9 MB/s | **3.6x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1020.7 MB/s | 1637.7 MB/s | **1.6x** | 2030.9 MB/s | 9682.6 MB/s | **4.8x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.1 MB/s | 1148.6 MB/s | **12.2x** | 1738.0 MB/s | 10479.4 MB/s | **6.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 96.2 MB/s | 1160.3 MB/s | **12.1x** | 2077.6 MB/s | 9503.6 MB/s | **4.6x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 15759.8 MB/s | 1817.3 MB/s | **0.1x** | 5959.2 MB/s | 5798.8 MB/s | **1.0x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10543.3 MB/s | 1342.5 MB/s | **0.1x** | 6448.9 MB/s | 5960.8 MB/s | **0.9x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 2108.9 MB/s | 608.7 MB/s | **0.3x** | 1933.8 MB/s | 3540.0 MB/s | **1.8x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 1998.7 MB/s | 611.0 MB/s | **0.3x** | 2003.2 MB/s | 3462.4 MB/s | **1.7x** |
