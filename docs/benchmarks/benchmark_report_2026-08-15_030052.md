# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 19:00:52 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 603.7 MB/s | 551.0 MB/s | **0.9x** | 602.8 MB/s | 330.0 MB/s | **0.5x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 497.2 MB/s | 742.1 MB/s | **1.5x** | 355.4 MB/s | 578.2 MB/s | **1.6x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 247.2 MB/s | 325.2 MB/s | **1.3x** | 525.4 MB/s | 1152.4 MB/s | **2.2x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 242.4 MB/s | 386.9 MB/s | **1.6x** | 423.7 MB/s | 645.4 MB/s | **1.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 364.7 MB/s | 1015.5 MB/s | **2.8x** | 525.2 MB/s | 1907.5 MB/s | **3.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 370.5 MB/s | 757.8 MB/s | **2.0x** | 283.1 MB/s | 1654.2 MB/s | **5.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 307.5 MB/s | 1184.5 MB/s | **3.9x** | 543.0 MB/s | 1867.1 MB/s | **3.4x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 221.2 MB/s | 887.3 MB/s | **4.0x** | 243.6 MB/s | 1916.7 MB/s | **7.9x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 194.1 MB/s | 841.5 MB/s | **4.3x** | 192.1 MB/s | 846.7 MB/s | **4.4x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 215.0 MB/s | 750.1 MB/s | **3.5x** | 197.9 MB/s | 699.8 MB/s | **3.5x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 856.2 MB/s | 2080.0 MB/s | **2.4x** | 1074.1 MB/s | 3250.5 MB/s | **3.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 751.3 MB/s | 1464.9 MB/s | **1.9x** | 719.1 MB/s | 1178.3 MB/s | **1.6x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 273.1 MB/s | 483.2 MB/s | **1.8x** | 815.8 MB/s | 2747.2 MB/s | **3.4x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 281.4 MB/s | 506.8 MB/s | **1.8x** | 558.5 MB/s | 1090.7 MB/s | **2.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 553.9 MB/s | 1540.5 MB/s | **2.8x** | 808.1 MB/s | 4109.3 MB/s | **5.1x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 536.5 MB/s | 1451.5 MB/s | **2.7x** | 670.0 MB/s | 3494.8 MB/s | **5.2x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 71.7 MB/s | 916.8 MB/s | **12.8x** | 760.2 MB/s | 3591.1 MB/s | **4.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 67.8 MB/s | 983.6 MB/s | **14.5x** | 833.0 MB/s | 3785.0 MB/s | **4.5x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1231.5 MB/s | 4873.7 MB/s | **4.0x** | 911.6 MB/s | 3953.4 MB/s | **4.3x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 947.6 MB/s | 2974.9 MB/s | **3.1x** | 1077.6 MB/s | 3913.0 MB/s | **3.6x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 581.3 MB/s | 2629.4 MB/s | **4.5x** | 715.3 MB/s | 4244.7 MB/s | **5.9x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 688.0 MB/s | 3253.4 MB/s | **4.7x** | 709.4 MB/s | 3383.7 MB/s | **4.8x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 110.3 MB/s | 2725.5 MB/s | **24.7x** | 2598.9 MB/s | 3728.5 MB/s | **1.4x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 105.7 MB/s | 839.1 MB/s | **7.9x** | 1750.3 MB/s | 3281.9 MB/s | **1.9x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 83.3 MB/s | 2932.2 MB/s | **35.2x** | 1385.8 MB/s | 3162.0 MB/s | **2.3x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 97.0 MB/s | 1132.2 MB/s | **11.7x** | 1289.1 MB/s | 3754.5 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 76.4 MB/s | 165.8 MB/s | **2.2x** | 2600.1 MB/s | 6663.3 MB/s | **2.6x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 74.3 MB/s | 151.0 MB/s | **2.0x** | 1376.7 MB/s | 1796.6 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 68.7 MB/s | 132.2 MB/s | **1.9x** | 2821.2 MB/s | 6105.9 MB/s | **2.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 58.3 MB/s | 134.8 MB/s | **2.3x** | 1505.7 MB/s | 1892.0 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4587.6 MB/s | 3434.1 MB/s | **0.7x** | 5336.0 MB/s | 4092.5 MB/s | **0.8x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 10.01 MB (10.0%) | 4956.3 MB/s | 9952.7 MB/s | **2.0x** | 5643.5 MB/s | 4359.4 MB/s | **0.8x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 779.4 MB/s | 1545.0 MB/s | **2.0x** | 1135.8 MB/s | 4822.4 MB/s | **4.2x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 498.0 MB/s | 956.0 MB/s | **1.9x** | 751.3 MB/s | 2122.2 MB/s | **2.8x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.10 MB (0.0%) | 3642.9 MB/s | 11290.0 MB/s | **3.1x** | 2923.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.10 MB (0.0%) | 3298.5 MB/s | 13726.5 MB/s | **4.2x** | 3047.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 466.3 MB/s | 11451.8 MB/s | **24.6x** | 2788.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 580.5 MB/s | 13721.6 MB/s | **23.6x** | 2935.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 987.2 MB/s | 1752.9 MB/s | **1.8x** | 1570.4 MB/s | 5296.6 MB/s | **3.4x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 994.8 MB/s | 1727.5 MB/s | **1.7x** | 1885.8 MB/s | 5250.7 MB/s | **2.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 91.2 MB/s | 1190.9 MB/s | **13.1x** | 1660.9 MB/s | 6356.8 MB/s | **3.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 92.9 MB/s | 1216.2 MB/s | **13.1x** | 1995.3 MB/s | 8905.7 MB/s | **4.5x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 15241.7 MB/s | 21046.5 MB/s | **1.4x** | 5885.3 MB/s | 4931.2 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10687.4 MB/s | 22405.5 MB/s | **2.1x** | 6436.6 MB/s | 5292.2 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 1966.4 MB/s | 7746.5 MB/s | **3.9x** | 1304.0 MB/s | 2667.9 MB/s | **2.0x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 1943.2 MB/s | 10215.4 MB/s | **5.3x** | 1987.8 MB/s | 3106.0 MB/s | **1.6x** | - |
