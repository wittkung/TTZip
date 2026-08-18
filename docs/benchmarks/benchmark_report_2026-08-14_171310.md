# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 09:13:10 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 846.9 MB/s | 680.1 MB/s | **0.8x** | 696.3 MB/s | 596.8 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 820.3 MB/s | 531.7 MB/s | **0.6x** | 521.0 MB/s | 237.3 MB/s | **0.5x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 284.9 MB/s | 406.8 MB/s | **1.4x** | 610.1 MB/s | 644.9 MB/s | **1.1x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 287.1 MB/s | 239.4 MB/s | **0.8x** | 471.3 MB/s | 430.9 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 472.5 MB/s | 1136.9 MB/s | **2.4x** | 571.1 MB/s | 1779.5 MB/s | **3.1x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 454.9 MB/s | 804.1 MB/s | **1.8x** | 295.1 MB/s | 1775.3 MB/s | **6.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 387.3 MB/s | 1194.1 MB/s | **3.1x** | 578.1 MB/s | 1908.3 MB/s | **3.3x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 355.6 MB/s | 808.9 MB/s | **2.3x** | 295.6 MB/s | 1729.9 MB/s | **5.9x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 268.2 MB/s | 982.2 MB/s | **3.7x** | 279.1 MB/s | 1034.5 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 268.1 MB/s | 1035.3 MB/s | **3.9x** | 269.9 MB/s | 1039.7 MB/s | **3.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 772.9 MB/s | 2589.0 MB/s | **3.3x** | 997.6 MB/s | 6010.1 MB/s | **6.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 913.1 MB/s | 737.9 MB/s | **0.8x** | 793.1 MB/s | 771.6 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 286.6 MB/s | 498.8 MB/s | **1.7x** | 943.0 MB/s | 1406.1 MB/s | **1.5x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 288.4 MB/s | 282.6 MB/s | **1.0x** | 605.5 MB/s | 613.1 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 614.5 MB/s | 1619.7 MB/s | **2.6x** | 866.2 MB/s | 5470.3 MB/s | **6.3x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 545.4 MB/s | 1483.5 MB/s | **2.7x** | 952.0 MB/s | 4187.1 MB/s | **4.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 74.8 MB/s | 1106.2 MB/s | **14.8x** | 903.0 MB/s | 4883.8 MB/s | **5.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 75.4 MB/s | 1138.4 MB/s | **15.1x** | 971.6 MB/s | 4615.5 MB/s | **4.8x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1438.3 MB/s | 2818.8 MB/s | **2.0x** | 1485.7 MB/s | 4461.3 MB/s | **3.0x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1198.1 MB/s | 3650.6 MB/s | **3.0x** | 1361.4 MB/s | 4295.9 MB/s | **3.2x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 681.9 MB/s | 3483.2 MB/s | **5.1x** | 831.0 MB/s | 5022.1 MB/s | **6.0x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 686.5 MB/s | 2922.5 MB/s | **4.3x** | 861.8 MB/s | 5027.5 MB/s | **5.8x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 169.7 MB/s | 4044.1 MB/s | **23.8x** | 3771.7 MB/s | 4927.1 MB/s | **1.3x** | 2_SolidBuf_IO_and_CRC32 (93.6%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.01 MB (100.0%) | 167.7 MB/s | 186.8 MB/s | **1.1x** | 2934.7 MB/s | 3123.2 MB/s | **1.1x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 121.1 MB/s | 3946.5 MB/s | **32.6x** | 1454.7 MB/s | 5369.6 MB/s | **3.7x** | 2_SolidBuf_IO_and_CRC32 (93.3%) |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 118.8 MB/s | 116.5 MB/s | **1.0x** | 1453.2 MB/s | 1401.0 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 82.9 MB/s | 185.3 MB/s | **2.2x** | 3255.5 MB/s | 9337.9 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 78.0 MB/s | 163.9 MB/s | **2.1x** | 1737.5 MB/s | 2143.2 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 69.4 MB/s | 146.9 MB/s | **2.1x** | 3279.4 MB/s | 10610.5 MB/s | **3.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 68.1 MB/s | 131.5 MB/s | **1.9x** | 1752.3 MB/s | 2220.1 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 10.09 MB (10.1%) | 5521.6 MB/s | 7910.3 MB/s | **1.4x** | 5887.1 MB/s | 6123.1 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 10.09 MB (10.1%) | 5778.8 MB/s | 8211.3 MB/s | **1.4x** | 5978.0 MB/s | 5898.6 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 807.2 MB/s | 1575.7 MB/s | **2.0x** | 1303.7 MB/s | 4967.9 MB/s | **3.8x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 854.3 MB/s | 1516.9 MB/s | **1.8x** | 1276.7 MB/s | 3989.7 MB/s | **3.1x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.14 MB (0.0%) | 4382.2 MB/s | 4310.5 MB/s | **1.0x** | 4499.4 MB/s | 8551.7 MB/s | **1.9x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.11 MB (0.0%) | 4869.4 MB/s | 4211.0 MB/s | **0.9x** | 4725.2 MB/s | 3849.5 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 578.6 MB/s | 2805.2 MB/s | **4.8x** | 3391.2 MB/s | 9372.4 MB/s | **2.8x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 585.7 MB/s | 583.5 MB/s | **1.0x** | 3138.7 MB/s | 3425.4 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 968.0 MB/s | 1705.9 MB/s | **1.8x** | 1568.2 MB/s | 8287.2 MB/s | **5.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 977.7 MB/s | 1741.8 MB/s | **1.8x** | 1927.4 MB/s | 8107.9 MB/s | **4.2x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 91.4 MB/s | 1184.6 MB/s | **13.0x** | 1687.8 MB/s | 11183.1 MB/s | **6.6x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 90.9 MB/s | 1163.3 MB/s | **12.8x** | 1886.7 MB/s | 9089.4 MB/s | **4.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 13125.9 MB/s | 9184.7 MB/s | **0.7x** | 5605.6 MB/s | 6374.3 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10787.5 MB/s | 11237.8 MB/s | **1.0x** | 6149.9 MB/s | 6634.3 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 1642.1 MB/s | 7549.2 MB/s | **4.6x** | 1386.9 MB/s | 2331.2 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 1602.3 MB/s | 4226.8 MB/s | **2.6x** | 1576.5 MB/s | 1906.4 MB/s | **1.2x** | - |
