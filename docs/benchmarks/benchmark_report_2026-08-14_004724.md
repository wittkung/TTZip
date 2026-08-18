# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-13 16:47:24 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 898.0 MB/s | 441.3 MB/s | **0.5x** | 689.1 MB/s | 576.4 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 867.9 MB/s | 241.1 MB/s | **0.3x** | 480.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 287.1 MB/s | 437.7 MB/s | **1.5x** | 564.6 MB/s | 657.7 MB/s | **1.2x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 284.6 MB/s | 243.3 MB/s | **0.9x** | 438.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 436.4 MB/s | 686.8 MB/s | **1.6x** | 446.4 MB/s | 1521.9 MB/s | **3.4x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 332.2 MB/s | 564.8 MB/s | **1.7x** | 304.5 MB/s | 257.2 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 356.5 MB/s | 662.2 MB/s | **1.9x** | 606.4 MB/s | 2018.3 MB/s | **3.3x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 335.6 MB/s | 571.8 MB/s | **1.7x** | 304.2 MB/s | 259.6 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 257.5 MB/s | 415.5 MB/s | **1.6x** | 276.2 MB/s | 962.6 MB/s | **3.5x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 268.3 MB/s | 410.9 MB/s | **1.5x** | 190.4 MB/s | 921.5 MB/s | **4.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1097.5 MB/s | 540.8 MB/s | **0.5x** | 1385.5 MB/s | 1842.5 MB/s | **1.3x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 954.4 MB/s | 285.4 MB/s | **0.3x** | 855.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 288.5 MB/s | 533.6 MB/s | **1.8x** | 958.2 MB/s | 1762.6 MB/s | **1.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 285.5 MB/s | 282.5 MB/s | **1.0x** | 679.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 661.0 MB/s | 1053.4 MB/s | **1.6x** | 1002.4 MB/s | 5936.9 MB/s | **5.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 660.2 MB/s | 1054.0 MB/s | **1.6x** | 1076.0 MB/s | 772.5 MB/s | **0.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 79.9 MB/s | 896.7 MB/s | **11.2x** | 965.4 MB/s | 6448.2 MB/s | **6.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 78.6 MB/s | 875.8 MB/s | **11.1x** | 969.0 MB/s | 770.8 MB/s | **0.8x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1542.7 MB/s | 1890.9 MB/s | **1.2x** | 1688.7 MB/s | 5631.0 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1271.1 MB/s | 1267.4 MB/s | **1.0x** | 1559.8 MB/s | 6068.8 MB/s | **3.9x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.3%) | 755.2 MB/s | 612.6 MB/s | **0.8x** | 917.5 MB/s | 4990.2 MB/s | **5.4x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 756.8 MB/s | 606.6 MB/s | **0.8x** | 920.9 MB/s | 5021.5 MB/s | **5.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 230.8 MB/s | 2602.4 MB/s | **11.3x** | 3904.5 MB/s | 6387.8 MB/s | **1.6x** | 2_SolidBuf_IO_and_CRC32 (96.8%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 234.9 MB/s | 195.4 MB/s | **0.8x** | 3179.6 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 144.0 MB/s | 2552.3 MB/s | **17.7x** | 1679.9 MB/s | 5662.3 MB/s | **3.4x** | 2_SolidBuf_IO_and_CRC32 (96.7%) |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 144.8 MB/s | 188.8 MB/s | **1.3x** | 1053.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 89.7 MB/s | 1803.9 MB/s | **20.1x** | 3632.7 MB/s | 9911.7 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 82.3 MB/s | 878.3 MB/s | **10.7x** | 1885.2 MB/s | 947.8 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 75.6 MB/s | 1952.1 MB/s | **25.8x** | 3804.8 MB/s | 10831.1 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 71.8 MB/s | 1127.6 MB/s | **15.7x** | 1878.3 MB/s | 949.3 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 6044.4 MB/s | 1378.7 MB/s | **0.2x** | 6871.5 MB/s | 6820.2 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 6280.9 MB/s | 1548.0 MB/s | **0.2x** | 6435.6 MB/s | 8966.1 MB/s | **1.4x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 1026.1 MB/s | 79.2 MB/s | **0.1x** | 1601.7 MB/s | 5236.4 MB/s | **3.3x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 1002.6 MB/s | 79.0 MB/s | **0.1x** | 1623.6 MB/s | 5703.0 MB/s | **3.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5094.6 MB/s | 3426.4 MB/s | **0.7x** | 5576.1 MB/s | 2067.5 MB/s | **0.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5088.3 MB/s | 673.5 MB/s | **0.1x** | 5120.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 677.9 MB/s | 3466.2 MB/s | **5.1x** | 3750.6 MB/s | 2030.7 MB/s | **0.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 673.7 MB/s | 671.6 MB/s | **1.0x** | 3552.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1022.0 MB/s | 590.1 MB/s | **0.6x** | 1806.7 MB/s | 7144.0 MB/s | **4.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1031.5 MB/s | 591.2 MB/s | **0.6x** | 2040.9 MB/s | 1495.4 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 96.6 MB/s | 504.8 MB/s | **5.2x** | 1765.4 MB/s | 11988.5 MB/s | **6.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 97.3 MB/s | 513.0 MB/s | **5.3x** | 2110.0 MB/s | 1571.4 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 14279.5 MB/s | 1846.4 MB/s | **0.1x** | 5844.1 MB/s | 7624.0 MB/s | **1.3x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 9770.9 MB/s | 1342.4 MB/s | **0.1x** | 6240.8 MB/s | 10058.3 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 2167.2 MB/s | 608.9 MB/s | **0.3x** | 1943.4 MB/s | 3247.8 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 2029.4 MB/s | 611.5 MB/s | **0.3x** | 1920.1 MB/s | 3351.7 MB/s | **1.7x** | - |
