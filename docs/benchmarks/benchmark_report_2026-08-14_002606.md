# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-13 16:26:06 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 867.5 MB/s | 420.7 MB/s | **0.5x** | 749.7 MB/s | 726.5 MB/s | **1.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 853.3 MB/s | 345.9 MB/s | **0.4x** | 440.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 285.5 MB/s | 419.1 MB/s | **1.5x** | 629.9 MB/s | 743.7 MB/s | **1.2x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 284.0 MB/s | 346.8 MB/s | **1.2x** | 490.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 439.2 MB/s | 700.4 MB/s | **1.6x** | 588.2 MB/s | 2045.7 MB/s | **3.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 410.9 MB/s | 571.4 MB/s | **1.4x** | 302.2 MB/s | 1833.2 MB/s | **6.1x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 356.3 MB/s | 683.6 MB/s | **1.9x** | 560.0 MB/s | 1885.0 MB/s | **3.4x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 329.0 MB/s | 546.6 MB/s | **1.7x** | 276.4 MB/s | 1446.4 MB/s | **5.2x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 279.5 MB/s | 411.3 MB/s | **1.5x** | 254.4 MB/s | 751.5 MB/s | **3.0x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 286.0 MB/s | 276.5 MB/s | **1.0x** | 258.5 MB/s | 506.3 MB/s | **2.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1058.5 MB/s | 496.8 MB/s | **0.5x** | 1355.0 MB/s | 1777.5 MB/s | **1.3x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 896.8 MB/s | 382.9 MB/s | **0.4x** | 805.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 283.1 MB/s | 505.0 MB/s | **1.8x** | 947.3 MB/s | 1839.2 MB/s | **1.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 285.4 MB/s | 385.9 MB/s | **1.4x** | 638.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 668.0 MB/s | 1069.7 MB/s | **1.6x** | 947.0 MB/s | 5677.2 MB/s | **6.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 533.0 MB/s | 1035.8 MB/s | **1.9x** | 930.6 MB/s | 4623.2 MB/s | **5.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 76.5 MB/s | 836.7 MB/s | **10.9x** | 938.6 MB/s | 5178.3 MB/s | **5.5x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 77.3 MB/s | 874.6 MB/s | **11.3x** | 998.8 MB/s | 4628.0 MB/s | **4.6x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1307.4 MB/s | 1865.4 MB/s | **1.4x** | 1642.9 MB/s | 5285.2 MB/s | **3.2x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1276.9 MB/s | 1439.1 MB/s | **1.1x** | 1567.3 MB/s | 5381.0 MB/s | **3.4x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.3%) | 778.5 MB/s | 608.5 MB/s | **0.8x** | 919.0 MB/s | 5380.0 MB/s | **5.9x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 781.7 MB/s | 601.8 MB/s | **0.8x** | 955.9 MB/s | 4952.5 MB/s | **5.2x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 237.3 MB/s | 2632.0 MB/s | **11.1x** | 4134.7 MB/s | 6168.6 MB/s | **1.5x** | 2_SolidBuf_IO_and_CRC32 (97.5%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 209.1 MB/s | 2679.7 MB/s | **12.8x** | 1985.2 MB/s | 6268.2 MB/s | **3.2x** | 2_SolidBuf_IO_and_CRC32 (97.4%) |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 146.2 MB/s | 2559.3 MB/s | **17.5x** | 1601.3 MB/s | 6335.9 MB/s | **4.0x** | 2_SolidBuf_IO_and_CRC32 (97.2%) |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 146.8 MB/s | 2584.2 MB/s | **17.6x** | 1597.5 MB/s | 6196.9 MB/s | **3.9x** | 2_SolidBuf_IO_and_CRC32 (97.2%) |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 91.4 MB/s | 1983.2 MB/s | **21.7x** | 3681.4 MB/s | 10560.9 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 82.2 MB/s | 890.0 MB/s | **10.8x** | 1823.9 MB/s | 2387.9 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 77.2 MB/s | 1927.6 MB/s | **25.0x** | 3689.7 MB/s | 9990.6 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 72.7 MB/s | 1080.0 MB/s | **14.8x** | 1841.6 MB/s | 2392.5 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5618.9 MB/s | 1344.6 MB/s | **0.2x** | 6761.9 MB/s | 6269.4 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 5450.8 MB/s | 1336.2 MB/s | **0.2x** | 3534.7 MB/s | 4201.2 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 966.3 MB/s | 76.2 MB/s | **0.1x** | 1659.8 MB/s | 4969.3 MB/s | **3.0x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 956.9 MB/s | 77.8 MB/s | **0.1x** | 1402.9 MB/s | 5110.6 MB/s | **3.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5084.7 MB/s | 3415.2 MB/s | **0.7x** | 5144.4 MB/s | 1917.3 MB/s | **0.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 4915.5 MB/s | 3196.4 MB/s | **0.7x** | 4701.7 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 661.3 MB/s | 2691.3 MB/s | **4.1x** | 3767.7 MB/s | 1748.4 MB/s | **0.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 671.4 MB/s | 3345.0 MB/s | **5.0x** | 3636.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1030.7 MB/s | 553.7 MB/s | **0.5x** | 1708.7 MB/s | 6994.4 MB/s | **4.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1027.0 MB/s | 596.6 MB/s | **0.6x** | 2041.5 MB/s | 9918.6 MB/s | **4.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 96.3 MB/s | 511.7 MB/s | **5.3x** | 1686.9 MB/s | 11148.4 MB/s | **6.6x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 92.9 MB/s | 510.2 MB/s | **5.5x** | 1950.7 MB/s | 10957.1 MB/s | **5.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 13924.9 MB/s | 1751.4 MB/s | **0.1x** | 5588.5 MB/s | 7495.2 MB/s | **1.3x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 8733.4 MB/s | 1153.6 MB/s | **0.1x** | 5932.2 MB/s | 9385.7 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 1871.7 MB/s | 596.1 MB/s | **0.3x** | 1783.6 MB/s | 3017.3 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 1862.0 MB/s | 590.1 MB/s | **0.3x** | 1636.5 MB/s | 2942.1 MB/s | **1.8x** | - |
