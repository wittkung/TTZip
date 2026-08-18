# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-10 09:59:44 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 779.9 MB/s | 267.2 MB/s | **0.3x** | 636.7 MB/s | 361.8 MB/s | **0.6x** |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 772.2 MB/s | 276.9 MB/s | **0.4x** | 483.4 MB/s | 461.2 MB/s | **1.0x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 280.5 MB/s | 284.0 MB/s | **1.0x** | 583.1 MB/s | 591.5 MB/s | **1.0x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 284.7 MB/s | 280.7 MB/s | **1.0x** | 467.0 MB/s | 441.1 MB/s | **0.9x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 387.1 MB/s | 5377.6 MB/s | **13.9x** | 568.7 MB/s | 2217.7 MB/s | **3.9x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 370.9 MB/s | 2070.2 MB/s | **5.6x** | 293.2 MB/s | 1793.5 MB/s | **6.1x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 313.3 MB/s | 5246.1 MB/s | **16.7x** | 581.0 MB/s | 2015.7 MB/s | **3.5x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 302.0 MB/s | 2090.5 MB/s | **6.9x** | 287.1 MB/s | 1781.6 MB/s | **6.2x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.07 MB (0.6%) | 207.2 MB/s | 164.4 MB/s | **0.8x** | 238.2 MB/s | 239.2 MB/s | **1.0x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.07 MB (0.6%) | 275.0 MB/s | 180.2 MB/s | **0.7x** | 234.1 MB/s | 232.6 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 912.8 MB/s | 280.8 MB/s | **0.3x** | 1175.2 MB/s | 822.9 MB/s | **0.7x** |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 776.5 MB/s | 278.3 MB/s | **0.4x** | 667.0 MB/s | 356.7 MB/s | **0.5x** |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 271.4 MB/s | 143.5 MB/s | **0.5x** | 847.7 MB/s | 777.2 MB/s | **0.9x** |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 209.9 MB/s | 202.2 MB/s | **1.0x** | 430.5 MB/s | 428.9 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 434.7 MB/s | 1221.4 MB/s | **2.8x** | 547.0 MB/s | 3117.7 MB/s | **5.7x** |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 374.6 MB/s | 1113.5 MB/s | **3.0x** | 562.8 MB/s | 3240.5 MB/s | **5.8x** |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 67.1 MB/s | 996.5 MB/s | **14.9x** | 618.7 MB/s | 2726.6 MB/s | **4.4x** |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 77.1 MB/s | 837.1 MB/s | **10.9x** | 832.1 MB/s | 3877.6 MB/s | **4.7x** |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1339.7 MB/s | 778.0 MB/s | **0.6x** | 1250.0 MB/s | 1100.5 MB/s | **0.9x** |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1062.5 MB/s | 715.3 MB/s | **0.7x** | 1053.0 MB/s | 983.6 MB/s | **0.9x** |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.7%) | 0.03 MB (0.3%) | 495.3 MB/s | 427.0 MB/s | **0.9x** | 417.5 MB/s | 1662.5 MB/s | **4.0x** |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 523.0 MB/s | 410.3 MB/s | **0.8x** | 451.5 MB/s | 1414.3 MB/s | **3.1x** |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 181.8 MB/s | 153.2 MB/s | **0.8x** | 3779.1 MB/s | 1465.5 MB/s | **0.4x** |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 185.1 MB/s | 173.5 MB/s | **0.9x** | 3094.5 MB/s | 1454.5 MB/s | **0.5x** |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 126.3 MB/s | 167.5 MB/s | **1.3x** | 1569.6 MB/s | 1520.4 MB/s | **1.0x** |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 129.4 MB/s | 151.7 MB/s | **1.2x** | 1405.0 MB/s | 1430.6 MB/s | **1.0x** |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 83.9 MB/s | 161.8 MB/s | **1.9x** | 3346.1 MB/s | 8031.8 MB/s | **2.4x** |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 81.4 MB/s | 173.3 MB/s | **2.1x** | 1706.5 MB/s | 2058.7 MB/s | **1.2x** |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 71.5 MB/s | 149.7 MB/s | **2.1x** | 3405.1 MB/s | 9223.6 MB/s | **2.7x** |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 67.9 MB/s | 142.0 MB/s | **2.1x** | 1669.3 MB/s | 1661.6 MB/s | **1.0x** |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5080.8 MB/s | 1307.5 MB/s | **0.3x** | 6369.0 MB/s | 1443.3 MB/s | **0.2x** |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 5102.2 MB/s | 1356.1 MB/s | **0.3x** | 6475.0 MB/s | 4099.4 MB/s | **0.6x** |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 818.6 MB/s | 75.0 MB/s | **0.1x** | 1311.4 MB/s | 3180.6 MB/s | **2.4x** |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 763.2 MB/s | 76.7 MB/s | **0.1x** | 1060.5 MB/s | 3999.1 MB/s | **3.8x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4610.1 MB/s | 593.8 MB/s | **0.1x** | 4290.0 MB/s | 3333.6 MB/s | **0.8x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4847.5 MB/s | 606.3 MB/s | **0.1x** | 4492.2 MB/s | 2453.3 MB/s | **0.5x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 650.8 MB/s | 628.9 MB/s | **1.0x** | 3506.2 MB/s | 3186.0 MB/s | **0.9x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 650.9 MB/s | 619.8 MB/s | **1.0x** | 3277.6 MB/s | 2857.2 MB/s | **0.9x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1006.1 MB/s | 1583.1 MB/s | **1.6x** | 1568.8 MB/s | 5824.8 MB/s | **3.7x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 969.9 MB/s | 1567.9 MB/s | **1.6x** | 1790.1 MB/s | 6150.3 MB/s | **3.4x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.0 MB/s | 1045.4 MB/s | **11.2x** | 1660.3 MB/s | 9040.3 MB/s | **5.4x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 92.7 MB/s | 1149.8 MB/s | **12.4x** | 1947.5 MB/s | 10084.1 MB/s | **5.2x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 13329.4 MB/s | 1650.4 MB/s | **0.1x** | 5464.9 MB/s | 4897.5 MB/s | **0.9x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 9571.8 MB/s | 1271.5 MB/s | **0.1x** | 5740.8 MB/s | 5092.3 MB/s | **0.9x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 2022.6 MB/s | 598.5 MB/s | **0.3x** | 1612.7 MB/s | 3192.2 MB/s | **2.0x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 1804.3 MB/s | 581.5 MB/s | **0.3x** | 1649.1 MB/s | 2477.8 MB/s | **1.5x** |
