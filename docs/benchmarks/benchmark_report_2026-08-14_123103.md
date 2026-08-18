# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 04:31:03 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 637.0 MB/s | 356.4 MB/s | **0.6x** | 664.1 MB/s | 542.2 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 796.5 MB/s | 216.4 MB/s | **0.3x** | 540.9 MB/s | 451.7 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 128.1 MB/s | 385.2 MB/s | **3.0x** | 600.6 MB/s | 590.0 MB/s | **1.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 265.9 MB/s | 235.9 MB/s | **0.9x** | 436.9 MB/s | 429.1 MB/s | **1.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 270.4 MB/s | 1123.4 MB/s | **4.2x** | 232.4 MB/s | 1828.2 MB/s | **7.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 35.4 MB/s | 717.0 MB/s | **20.3x** | 252.7 MB/s | 1536.5 MB/s | **6.1x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 194.9 MB/s | 1027.1 MB/s | **5.3x** | 444.7 MB/s | 1558.4 MB/s | **3.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 215.4 MB/s | 553.1 MB/s | **2.6x** | 256.5 MB/s | 1475.7 MB/s | **5.8x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 232.3 MB/s | 344.9 MB/s | **1.5x** | 240.8 MB/s | 584.2 MB/s | **2.4x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 217.2 MB/s | 382.0 MB/s | **1.8x** | 246.8 MB/s | 432.6 MB/s | **1.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 992.2 MB/s | 401.9 MB/s | **0.4x** | 1277.0 MB/s | 1696.3 MB/s | **1.3x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 861.4 MB/s | 282.6 MB/s | **0.3x** | 779.8 MB/s | 604.3 MB/s | **0.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 284.1 MB/s | 464.3 MB/s | **1.6x** | 917.8 MB/s | 1686.5 MB/s | **1.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 256.0 MB/s | 249.5 MB/s | **1.0x** | 624.6 MB/s | 558.3 MB/s | **0.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 645.7 MB/s | 1600.0 MB/s | **2.5x** | 920.8 MB/s | 3997.9 MB/s | **4.3x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 618.7 MB/s | 1527.2 MB/s | **2.5x** | 353.4 MB/s | 3306.1 MB/s | **9.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 74.5 MB/s | 1205.7 MB/s | **16.2x** | 911.6 MB/s | 6127.4 MB/s | **6.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 75.2 MB/s | 1119.6 MB/s | **14.9x** | 967.7 MB/s | 4324.5 MB/s | **4.5x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1403.7 MB/s | 1289.6 MB/s | **0.9x** | 1423.9 MB/s | 5195.1 MB/s | **3.6x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1086.4 MB/s | 1327.2 MB/s | **1.2x** | 1339.1 MB/s | 4799.1 MB/s | **3.6x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.3%) | 744.0 MB/s | 564.4 MB/s | **0.8x** | 878.9 MB/s | 4848.4 MB/s | **5.5x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 714.3 MB/s | 570.3 MB/s | **0.8x** | 904.4 MB/s | 4238.6 MB/s | **4.7x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 153.5 MB/s | 1862.0 MB/s | **12.1x** | 3420.2 MB/s | 4898.1 MB/s | **1.4x** | 2_SolidBuf_IO_and_CRC32 (98.3%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 160.2 MB/s | 143.0 MB/s | **0.9x** | 2985.4 MB/s | 1358.7 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 128.0 MB/s | 3573.5 MB/s | **27.9x** | 1502.0 MB/s | 5095.5 MB/s | **3.4x** | 2_SolidBuf_IO_and_CRC32 (92.8%) |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 129.0 MB/s | 163.5 MB/s | **1.3x** | 1387.7 MB/s | 1350.2 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 87.3 MB/s | 155.1 MB/s | **1.8x** | 3341.5 MB/s | 8271.7 MB/s | **2.5x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 79.3 MB/s | 142.1 MB/s | **1.8x** | 1561.7 MB/s | 1435.1 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 74.0 MB/s | 132.7 MB/s | **1.8x** | 3324.7 MB/s | 8647.2 MB/s | **2.6x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 67.5 MB/s | 132.1 MB/s | **2.0x** | 1630.7 MB/s | 1818.5 MB/s | **1.1x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4491.8 MB/s | 1123.3 MB/s | **0.3x** | 6320.3 MB/s | 4398.1 MB/s | **0.7x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 19.01 MB (19.0%) | 3884.1 MB/s | 1539.1 MB/s | **0.4x** | 6033.5 MB/s | 5984.8 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 888.0 MB/s | 77.1 MB/s | **0.1x** | 1484.8 MB/s | 3841.7 MB/s | **2.6x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 807.0 MB/s | 77.0 MB/s | **0.1x** | 1242.3 MB/s | 4417.5 MB/s | **3.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 4137.5 MB/s | 1783.3 MB/s | **0.4x** | 3858.2 MB/s | 1819.0 MB/s | **0.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 3745.3 MB/s | 441.6 MB/s | **0.1x** | 4024.9 MB/s | 2511.8 MB/s | **0.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 609.6 MB/s | 3198.6 MB/s | **5.2x** | 3130.5 MB/s | 1874.9 MB/s | **0.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 615.8 MB/s | 600.9 MB/s | **1.0x** | 3267.0 MB/s | 3103.1 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 996.2 MB/s | 1797.5 MB/s | **1.8x** | 1642.3 MB/s | 5359.6 MB/s | **3.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 976.5 MB/s | 1715.5 MB/s | **1.8x** | 1871.3 MB/s | 5153.3 MB/s | **2.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 92.2 MB/s | 1203.3 MB/s | **13.0x** | 1633.2 MB/s | 4959.0 MB/s | **3.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 92.0 MB/s | 1210.7 MB/s | **13.2x** | 1944.0 MB/s | 6317.7 MB/s | **3.2x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10361.6 MB/s | 1621.0 MB/s | **0.2x** | 5119.8 MB/s | 6802.1 MB/s | **1.3x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 7567.6 MB/s | 1420.2 MB/s | **0.2x** | 4831.0 MB/s | 7282.2 MB/s | **1.5x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 2000.4 MB/s | 585.2 MB/s | **0.3x** | 1749.0 MB/s | 2919.3 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 1783.2 MB/s | 590.3 MB/s | **0.3x** | 1924.2 MB/s | 2921.0 MB/s | **1.5x** | - |
