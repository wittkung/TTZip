# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 18:56:23 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 869.6 MB/s | 712.4 MB/s | **0.8x** | 733.3 MB/s | 1171.6 MB/s | **1.6x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 851.4 MB/s | 714.8 MB/s | **0.8x** | 502.0 MB/s | 840.3 MB/s | **1.7x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 288.1 MB/s | 383.3 MB/s | **1.3x** | 634.7 MB/s | 1104.5 MB/s | **1.7x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 289.3 MB/s | 415.6 MB/s | **1.4x** | 483.6 MB/s | 738.5 MB/s | **1.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 482.6 MB/s | 1263.7 MB/s | **2.6x** | 603.9 MB/s | 1966.9 MB/s | **3.3x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 444.8 MB/s | 915.7 MB/s | **2.1x** | 299.3 MB/s | 1626.1 MB/s | **5.4x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 387.5 MB/s | 1229.7 MB/s | **3.2x** | 587.0 MB/s | 1866.0 MB/s | **3.2x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 361.1 MB/s | 885.9 MB/s | **2.5x** | 293.4 MB/s | 1862.6 MB/s | **6.3x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 261.5 MB/s | 996.2 MB/s | **3.8x** | 272.2 MB/s | 873.3 MB/s | **3.2x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 253.2 MB/s | 1028.0 MB/s | **4.1x** | 245.7 MB/s | 824.3 MB/s | **3.4x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1071.6 MB/s | 2787.7 MB/s | **2.6x** | 1417.3 MB/s | 5735.9 MB/s | **4.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 930.4 MB/s | 1554.3 MB/s | **1.7x** | 836.5 MB/s | 1338.7 MB/s | **1.6x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 296.4 MB/s | 524.9 MB/s | **1.8x** | 974.7 MB/s | 3935.0 MB/s | **4.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 291.2 MB/s | 553.3 MB/s | **1.9x** | 670.7 MB/s | 1220.1 MB/s | **1.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 660.6 MB/s | 1744.6 MB/s | **2.6x** | 973.1 MB/s | 5274.1 MB/s | **5.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 646.7 MB/s | 1535.8 MB/s | **2.4x** | 1034.8 MB/s | 4807.0 MB/s | **4.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 77.3 MB/s | 1249.1 MB/s | **16.2x** | 967.9 MB/s | 6812.3 MB/s | **7.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 76.8 MB/s | 1162.0 MB/s | **15.1x** | 1024.6 MB/s | 5281.1 MB/s | **5.2x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1690.6 MB/s | 4911.4 MB/s | **2.9x** | 1605.8 MB/s | 5390.3 MB/s | **3.4x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1327.6 MB/s | 3693.2 MB/s | **2.8x** | 1578.0 MB/s | 5729.0 MB/s | **3.6x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 772.3 MB/s | 4220.8 MB/s | **5.5x** | 930.1 MB/s | 6018.1 MB/s | **6.5x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 769.6 MB/s | 4651.7 MB/s | **6.0x** | 930.6 MB/s | 5659.9 MB/s | **6.1x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 216.2 MB/s | 4245.2 MB/s | **19.6x** | 4368.8 MB/s | 5894.9 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 215.9 MB/s | 1191.6 MB/s | **5.5x** | 3252.5 MB/s | 4740.9 MB/s | **1.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 139.8 MB/s | 4929.9 MB/s | **35.3x** | 1535.6 MB/s | 6573.3 MB/s | **4.3x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 141.2 MB/s | 1257.4 MB/s | **8.9x** | 1534.1 MB/s | 5486.2 MB/s | **3.6x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 89.2 MB/s | 184.2 MB/s | **2.1x** | 3941.4 MB/s | 10693.2 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 79.7 MB/s | 172.1 MB/s | **2.2x** | 1850.9 MB/s | 2279.8 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 73.2 MB/s | 145.9 MB/s | **2.0x** | 3570.9 MB/s | 10264.5 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.1 MB/s | 139.5 MB/s | **2.0x** | 1817.4 MB/s | 2386.4 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 6243.1 MB/s | 4776.4 MB/s | **0.8x** | 6561.7 MB/s | 5358.3 MB/s | **0.8x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 6084.6 MB/s | 4928.7 MB/s | **0.8x** | 6170.3 MB/s | 6549.3 MB/s | **1.1x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 1003.0 MB/s | 1758.6 MB/s | **1.8x** | 1656.7 MB/s | 5800.6 MB/s | **3.5x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 966.3 MB/s | 1747.2 MB/s | **1.8x** | 1601.6 MB/s | 5530.7 MB/s | **3.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.10 MB (0.0%) | 5485.1 MB/s | 20937.7 MB/s | **3.8x** | 5684.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.10 MB (0.0%) | 5454.6 MB/s | 21380.2 MB/s | **3.9x** | 5185.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 677.2 MB/s | 19787.5 MB/s | **29.2x** | 3720.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 669.5 MB/s | 17578.5 MB/s | **26.3x** | 3645.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 998.3 MB/s | 1846.0 MB/s | **1.8x** | 1720.8 MB/s | 6720.3 MB/s | **3.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1032.4 MB/s | 1840.6 MB/s | **1.8x** | 2007.2 MB/s | 7264.2 MB/s | **3.6x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.0 MB/s | 1256.3 MB/s | **13.4x** | 1648.3 MB/s | 11603.7 MB/s | **7.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.4 MB/s | 940.5 MB/s | **10.1x** | 1776.1 MB/s | 9107.0 MB/s | **5.1x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 13145.3 MB/s | 21206.6 MB/s | **1.6x** | 5651.4 MB/s | 7742.7 MB/s | **1.4x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10894.1 MB/s | 21765.9 MB/s | **2.0x** | 6142.8 MB/s | 8541.1 MB/s | **1.4x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2083.9 MB/s | 8458.7 MB/s | **4.1x** | 1922.7 MB/s | 2819.1 MB/s | **1.5x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 1952.4 MB/s | 10802.0 MB/s | **5.5x** | 2016.7 MB/s | 3199.9 MB/s | **1.6x** | - |
