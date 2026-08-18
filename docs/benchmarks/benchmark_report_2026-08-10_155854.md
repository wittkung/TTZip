# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-10 07:58:54 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 906.4 MB/s | 288.9 MB/s | **0.3x** | 720.2 MB/s | 0.0 MB/s | **0.0x** |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 885.5 MB/s | 288.1 MB/s | **0.3x** | 509.8 MB/s | 0.0 MB/s | **0.0x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 290.4 MB/s | 290.2 MB/s | **1.0x** | 627.9 MB/s | 0.0 MB/s | **0.0x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 286.5 MB/s | 288.4 MB/s | **1.0x** | 476.8 MB/s | 0.0 MB/s | **0.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 441.4 MB/s | 4873.2 MB/s | **11.0x** | 593.6 MB/s | 761.2 MB/s | **1.3x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 400.5 MB/s | 2305.7 MB/s | **5.8x** | 297.9 MB/s | 1903.7 MB/s | **6.4x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 349.1 MB/s | 5407.1 MB/s | **15.5x** | 587.6 MB/s | 2015.6 MB/s | **3.4x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 321.9 MB/s | 2107.8 MB/s | **6.5x** | 298.3 MB/s | 1988.5 MB/s | **6.7x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.07 MB (0.6%) | 292.1 MB/s | 229.9 MB/s | **0.8x** | 255.7 MB/s | 317.9 MB/s | **1.2x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.07 MB (0.6%) | 289.6 MB/s | 224.1 MB/s | **0.8x** | 260.6 MB/s | 231.3 MB/s | **0.9x** |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1038.6 MB/s | 279.3 MB/s | **0.3x** | 1271.1 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 858.5 MB/s | 283.5 MB/s | **0.3x** | 728.8 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 288.0 MB/s | 288.6 MB/s | **1.0x** | 901.7 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 281.4 MB/s | 282.5 MB/s | **1.0x** | 600.6 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 659.4 MB/s | 1618.8 MB/s | **2.5x** | 913.9 MB/s | 4662.5 MB/s | **5.1x** |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 642.8 MB/s | 1482.8 MB/s | **2.3x** | 990.3 MB/s | 4428.5 MB/s | **4.5x** |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 80.9 MB/s | 1159.9 MB/s | **14.3x** | 870.3 MB/s | 5287.6 MB/s | **6.1x** |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 80.2 MB/s | 1102.4 MB/s | **13.7x** | 932.9 MB/s | 4630.7 MB/s | **5.0x** |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1332.7 MB/s | 986.9 MB/s | **0.7x** | 1387.1 MB/s | 762.8 MB/s | **0.5x** |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1111.8 MB/s | 861.4 MB/s | **0.8x** | 1415.8 MB/s | 767.2 MB/s | **0.5x** |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.7%) | 0.03 MB (0.3%) | 734.1 MB/s | 478.2 MB/s | **0.7x** | 842.6 MB/s | 554.2 MB/s | **0.7x** |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 708.0 MB/s | 479.8 MB/s | **0.7x** | 876.9 MB/s | 530.6 MB/s | **0.6x** |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 211.6 MB/s | 183.2 MB/s | **0.9x** | 3979.6 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 181.7 MB/s | 179.4 MB/s | **1.0x** | 3111.8 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 141.3 MB/s | 167.1 MB/s | **1.2x** | 1615.0 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 140.9 MB/s | 125.5 MB/s | **0.9x** | 1466.9 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 87.5 MB/s | 196.2 MB/s | **2.2x** | 3409.9 MB/s | 7182.0 MB/s | **2.1x** |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 82.3 MB/s | 181.4 MB/s | **2.2x** | 1707.9 MB/s | 2124.7 MB/s | **1.2x** |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 74.6 MB/s | 154.7 MB/s | **2.1x** | 3583.6 MB/s | 6763.1 MB/s | **1.9x** |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 69.4 MB/s | 143.8 MB/s | **2.1x** | 1745.8 MB/s | 2161.2 MB/s | **1.2x** |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5011.7 MB/s | 997.2 MB/s | **0.2x** | 5717.3 MB/s | 2175.9 MB/s | **0.4x** |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 3580.0 MB/s | 1179.9 MB/s | **0.3x** | 5671.2 MB/s | 2454.8 MB/s | **0.4x** |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 897.4 MB/s | 69.2 MB/s | **0.1x** | 1619.1 MB/s | 1632.2 MB/s | **1.0x** |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 943.0 MB/s | 77.2 MB/s | **0.1x** | 1695.8 MB/s | 1692.3 MB/s | **1.0x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5185.1 MB/s | 664.0 MB/s | **0.1x** | 5110.4 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5241.8 MB/s | 650.4 MB/s | **0.1x** | 5256.4 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 673.4 MB/s | 640.7 MB/s | **1.0x** | 3840.4 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 660.8 MB/s | 639.4 MB/s | **1.0x** | 3563.3 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1019.2 MB/s | 1617.6 MB/s | **1.6x** | 1705.3 MB/s | 6494.9 MB/s | **3.8x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1009.0 MB/s | 1608.8 MB/s | **1.6x** | 2075.0 MB/s | 7039.3 MB/s | **3.4x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.2 MB/s | 1133.4 MB/s | **12.0x** | 1718.2 MB/s | 11646.7 MB/s | **6.8x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.6 MB/s | 1151.5 MB/s | **12.2x** | 2069.9 MB/s | 11302.9 MB/s | **5.5x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 14768.1 MB/s | 1734.6 MB/s | **0.1x** | 5187.1 MB/s | 3664.3 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 9924.5 MB/s | 1238.7 MB/s | **0.1x** | 6152.5 MB/s | 3784.0 MB/s | **0.6x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 2234.1 MB/s | 599.2 MB/s | **0.3x** | 1865.2 MB/s | 1387.2 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 2004.4 MB/s | 602.1 MB/s | **0.3x** | 1919.6 MB/s | 1319.7 MB/s | **0.7x** |
