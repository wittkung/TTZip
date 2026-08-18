# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 21:25:41 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 769.5 MB/s | 855.0 MB/s | **1.1x** | 676.4 MB/s | 1472.2 MB/s | **2.2x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 840.6 MB/s | 847.1 MB/s | **1.0x** | 565.7 MB/s | 1413.7 MB/s | **2.5x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 296.2 MB/s | 403.9 MB/s | **1.4x** | 561.7 MB/s | 1364.7 MB/s | **2.4x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 285.8 MB/s | 419.3 MB/s | **1.5x** | 480.1 MB/s | 1419.2 MB/s | **3.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 461.8 MB/s | 1219.1 MB/s | **2.6x** | 581.3 MB/s | 2066.9 MB/s | **3.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 433.8 MB/s | 876.2 MB/s | **2.0x** | 293.8 MB/s | 1856.0 MB/s | **6.3x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 354.8 MB/s | 1149.1 MB/s | **3.2x** | 554.7 MB/s | 2047.9 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 317.8 MB/s | 873.1 MB/s | **2.7x** | 275.1 MB/s | 1744.2 MB/s | **6.3x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 206.6 MB/s | 917.4 MB/s | **4.4x** | 265.9 MB/s | 840.8 MB/s | **3.2x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 230.6 MB/s | 1017.2 MB/s | **4.4x** | 283.8 MB/s | 1086.7 MB/s | **3.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1066.4 MB/s | 1988.6 MB/s | **1.9x** | 1427.1 MB/s | 4785.4 MB/s | **3.4x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 854.8 MB/s | 2456.1 MB/s | **2.9x** | 809.7 MB/s | 5846.2 MB/s | **7.2x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 272.4 MB/s | 550.1 MB/s | **2.0x** | 929.6 MB/s | 3517.5 MB/s | **3.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 297.6 MB/s | 542.6 MB/s | **1.8x** | 651.8 MB/s | 3871.3 MB/s | **5.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 639.8 MB/s | 1722.5 MB/s | **2.7x** | 924.3 MB/s | 6035.2 MB/s | **6.5x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 631.5 MB/s | 1607.7 MB/s | **2.5x** | 990.0 MB/s | 4703.1 MB/s | **4.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 76.8 MB/s | 1230.4 MB/s | **16.0x** | 921.3 MB/s | 6835.3 MB/s | **7.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 75.6 MB/s | 1138.0 MB/s | **15.1x** | 972.7 MB/s | 4571.9 MB/s | **4.7x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1389.8 MB/s | 6474.3 MB/s | **4.7x** | 1465.5 MB/s | 4502.8 MB/s | **3.1x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1293.2 MB/s | 5216.3 MB/s | **4.0x** | 1553.2 MB/s | 4984.5 MB/s | **3.2x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 755.4 MB/s | 4614.1 MB/s | **6.1x** | 903.5 MB/s | 4779.3 MB/s | **5.3x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 715.4 MB/s | 4273.6 MB/s | **6.0x** | 905.9 MB/s | 4639.8 MB/s | **5.1x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 200.2 MB/s | 5708.6 MB/s | **28.5x** | 3963.0 MB/s | 5734.6 MB/s | **1.4x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 219.5 MB/s | 1326.2 MB/s | **6.0x** | 3255.2 MB/s | 6580.0 MB/s | **2.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 145.0 MB/s | 5506.9 MB/s | **38.0x** | 1673.4 MB/s | 6299.3 MB/s | **3.8x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 143.7 MB/s | 1392.8 MB/s | **9.7x** | 1490.4 MB/s | 7077.1 MB/s | **4.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 88.1 MB/s | 186.4 MB/s | **2.1x** | 3777.2 MB/s | 10275.0 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 83.8 MB/s | 175.9 MB/s | **2.1x** | 1804.2 MB/s | 2326.9 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 75.1 MB/s | 148.5 MB/s | **2.0x** | 3714.7 MB/s | 9859.7 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.4 MB/s | 141.2 MB/s | **2.0x** | 1833.9 MB/s | 2407.5 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5755.4 MB/s | 5460.0 MB/s | **0.9x** | 5368.9 MB/s | 4120.5 MB/s | **0.8x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 5838.5 MB/s | 4846.4 MB/s | **0.8x** | 5046.2 MB/s | 3798.2 MB/s | **0.8x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 1044.2 MB/s | 1771.7 MB/s | **1.7x** | 1613.5 MB/s | 5680.4 MB/s | **3.5x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 995.0 MB/s | 1316.8 MB/s | **1.3x** | 1706.4 MB/s | 5782.6 MB/s | **3.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 6030.4 MB/s | 5014.4 MB/s | **0.8x** | 6017.0 MB/s | 9123.8 MB/s | **1.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5785.6 MB/s | 5040.7 MB/s | **0.9x** | 5180.9 MB/s | 9596.8 MB/s | **1.9x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 689.2 MB/s | 5022.6 MB/s | **7.3x** | 3694.9 MB/s | 9670.2 MB/s | **2.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 686.8 MB/s | 5047.5 MB/s | **7.3x** | 3498.0 MB/s | 9747.6 MB/s | **2.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1025.0 MB/s | 1864.8 MB/s | **1.8x** | 1815.4 MB/s | 10817.3 MB/s | **6.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1042.5 MB/s | 1871.4 MB/s | **1.8x** | 2135.7 MB/s | 10830.3 MB/s | **5.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 97.7 MB/s | 1274.0 MB/s | **13.0x** | 1791.4 MB/s | 12379.9 MB/s | **6.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 97.2 MB/s | 1259.7 MB/s | **13.0x** | 1991.6 MB/s | 12023.9 MB/s | **6.0x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 15736.7 MB/s | 21611.4 MB/s | **1.4x** | 5423.7 MB/s | 4944.8 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 11110.3 MB/s | 23632.0 MB/s | **2.1x** | 5875.4 MB/s | 4774.5 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2256.6 MB/s | 11373.0 MB/s | **5.0x** | 1929.2 MB/s | 3238.2 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2113.8 MB/s | 11277.3 MB/s | **5.3x** | 2043.6 MB/s | 3285.6 MB/s | **1.6x** | - |
