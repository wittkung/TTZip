# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 04:29:22 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 630.9 MB/s | 331.0 MB/s | **0.5x** | 621.0 MB/s | 398.8 MB/s | **0.6x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 787.5 MB/s | 233.9 MB/s | **0.3x** | 523.1 MB/s | 406.4 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 276.8 MB/s | 374.0 MB/s | **1.4x** | 533.1 MB/s | 475.8 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 274.3 MB/s | 227.9 MB/s | **0.8x** | 410.3 MB/s | 422.3 MB/s | **1.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 59.8 MB/s | 374.6 MB/s | **6.3x** | 572.8 MB/s | 1605.4 MB/s | **2.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 212.5 MB/s | 898.4 MB/s | **4.2x** | 282.4 MB/s | 1665.9 MB/s | **5.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 310.0 MB/s | 1235.6 MB/s | **4.0x** | 564.8 MB/s | 2022.1 MB/s | **3.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 303.0 MB/s | 898.1 MB/s | **3.0x** | 296.6 MB/s | 1793.8 MB/s | **6.0x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 202.1 MB/s | 396.7 MB/s | **2.0x** | 264.9 MB/s | 590.9 MB/s | **2.2x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 240.2 MB/s | 395.4 MB/s | **1.6x** | 223.0 MB/s | 688.6 MB/s | **3.1x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 977.2 MB/s | 426.8 MB/s | **0.4x** | 1262.5 MB/s | 1691.4 MB/s | **1.3x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 793.9 MB/s | 273.7 MB/s | **0.3x** | 758.7 MB/s | 597.7 MB/s | **0.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 272.7 MB/s | 444.9 MB/s | **1.6x** | 902.7 MB/s | 1498.6 MB/s | **1.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 267.7 MB/s | 249.3 MB/s | **0.9x** | 614.1 MB/s | 592.2 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 609.2 MB/s | 1615.5 MB/s | **2.7x** | 858.6 MB/s | 3836.3 MB/s | **4.5x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 593.7 MB/s | 1271.0 MB/s | **2.1x** | 908.4 MB/s | 2861.5 MB/s | **3.1x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 74.3 MB/s | 964.9 MB/s | **13.0x** | 886.4 MB/s | 4061.0 MB/s | **4.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 74.3 MB/s | 883.5 MB/s | **11.9x** | 959.0 MB/s | 2436.3 MB/s | **2.5x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1204.0 MB/s | 1330.4 MB/s | **1.1x** | 1449.7 MB/s | 4835.3 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1165.4 MB/s | 1262.2 MB/s | **1.1x** | 1458.5 MB/s | 5445.0 MB/s | **3.7x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.3%) | 729.6 MB/s | 565.1 MB/s | **0.8x** | 887.8 MB/s | 4851.9 MB/s | **5.5x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 733.5 MB/s | 572.1 MB/s | **0.8x** | 883.1 MB/s | 4471.2 MB/s | **5.1x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 177.8 MB/s | 1732.2 MB/s | **9.7x** | 3850.3 MB/s | 5068.6 MB/s | **1.3x** | 2_SolidBuf_IO_and_CRC32 (98.4%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 175.9 MB/s | 172.9 MB/s | **1.0x** | 3027.2 MB/s | 1413.8 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 129.2 MB/s | 3640.1 MB/s | **28.2x** | 1479.9 MB/s | 5384.1 MB/s | **3.6x** | 2_SolidBuf_IO_and_CRC32 (91.5%) |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 126.7 MB/s | 165.9 MB/s | **1.3x** | 1406.6 MB/s | 1132.9 MB/s | **0.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 83.0 MB/s | 176.4 MB/s | **2.1x** | 3440.4 MB/s | 8561.8 MB/s | **2.5x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 79.7 MB/s | 160.3 MB/s | **2.0x** | 1702.8 MB/s | 2178.7 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 73.7 MB/s | 132.4 MB/s | **1.8x** | 3262.6 MB/s | 9299.1 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 69.0 MB/s | 122.3 MB/s | **1.8x** | 1627.9 MB/s | 2163.5 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 3070.9 MB/s | 906.7 MB/s | **0.3x** | 5995.6 MB/s | 4287.4 MB/s | **0.7x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 19.01 MB (19.0%) | 5040.1 MB/s | 1388.1 MB/s | **0.3x** | 6107.7 MB/s | 6208.3 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 685.8 MB/s | 41.1 MB/s | **0.1x** | 1443.9 MB/s | 3473.4 MB/s | **2.4x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 823.8 MB/s | 76.8 MB/s | **0.1x** | 1088.7 MB/s | 4352.0 MB/s | **4.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 4671.0 MB/s | 1945.4 MB/s | **0.4x** | 5248.0 MB/s | 1905.9 MB/s | **0.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4732.1 MB/s | 595.2 MB/s | **0.1x** | 4508.7 MB/s | 3276.3 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 654.5 MB/s | 4371.1 MB/s | **6.7x** | 3432.7 MB/s | 1963.7 MB/s | **0.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 619.1 MB/s | 424.1 MB/s | **0.7x** | 3031.4 MB/s | 2819.0 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 991.2 MB/s | 1801.6 MB/s | **1.8x** | 1643.5 MB/s | 5244.0 MB/s | **3.2x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 914.8 MB/s | 1787.1 MB/s | **2.0x** | 1890.8 MB/s | 4858.9 MB/s | **2.6x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 91.1 MB/s | 1217.5 MB/s | **13.4x** | 1627.3 MB/s | 5724.2 MB/s | **3.5x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 92.3 MB/s | 1216.6 MB/s | **13.2x** | 1958.8 MB/s | 5523.2 MB/s | **2.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 12227.5 MB/s | 1845.2 MB/s | **0.2x** | 4918.0 MB/s | 7680.9 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 9055.8 MB/s | 1815.0 MB/s | **0.2x** | 5924.9 MB/s | 7719.8 MB/s | **1.3x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 1877.4 MB/s | 580.9 MB/s | **0.3x** | 1759.5 MB/s | 2857.1 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 1859.8 MB/s | 577.5 MB/s | **0.3x** | 1568.1 MB/s | 2571.0 MB/s | **1.6x** | - |
