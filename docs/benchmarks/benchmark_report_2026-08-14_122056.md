# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 04:20:56 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 878.6 MB/s | 304.2 MB/s | **0.3x** | 669.9 MB/s | 489.2 MB/s | **0.7x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 856.4 MB/s | 241.7 MB/s | **0.3x** | 561.2 MB/s | 475.8 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 286.9 MB/s | 412.0 MB/s | **1.4x** | 619.0 MB/s | 643.7 MB/s | **1.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 283.8 MB/s | 237.1 MB/s | **0.8x** | 390.1 MB/s | 464.3 MB/s | **1.2x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 435.5 MB/s | 1283.4 MB/s | **2.9x** | 602.3 MB/s | 1997.1 MB/s | **3.3x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 407.9 MB/s | 909.2 MB/s | **2.2x** | 307.5 MB/s | 1670.6 MB/s | **5.4x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 357.1 MB/s | 1239.0 MB/s | **3.5x** | 601.1 MB/s | 2116.8 MB/s | **3.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 334.8 MB/s | 919.2 MB/s | **2.7x** | 305.5 MB/s | 1962.6 MB/s | **6.4x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 275.0 MB/s | 407.9 MB/s | **1.5x** | 262.4 MB/s | 1030.0 MB/s | **3.9x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 244.3 MB/s | 354.5 MB/s | **1.5x** | 238.8 MB/s | 848.3 MB/s | **3.6x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 820.0 MB/s | 467.7 MB/s | **0.6x** | 924.6 MB/s | 1564.7 MB/s | **1.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 866.1 MB/s | 145.8 MB/s | **0.2x** | 758.2 MB/s | 524.1 MB/s | **0.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 280.6 MB/s | 472.5 MB/s | **1.7x** | 905.0 MB/s | 1756.7 MB/s | **1.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 283.8 MB/s | 284.8 MB/s | **1.0x** | 621.5 MB/s | 609.6 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 635.9 MB/s | 1632.2 MB/s | **2.6x** | 904.1 MB/s | 5466.9 MB/s | **6.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 619.5 MB/s | 1480.4 MB/s | **2.4x** | 971.5 MB/s | 3956.5 MB/s | **4.1x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 74.8 MB/s | 1176.5 MB/s | **15.7x** | 896.4 MB/s | 5574.6 MB/s | **6.2x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 76.2 MB/s | 1110.2 MB/s | **14.6x** | 949.9 MB/s | 4859.4 MB/s | **5.1x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1298.1 MB/s | 1549.1 MB/s | **1.2x** | 1481.2 MB/s | 5579.2 MB/s | **3.8x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1248.8 MB/s | 1503.5 MB/s | **1.2x** | 1485.7 MB/s | 5991.7 MB/s | **4.0x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.3%) | 702.4 MB/s | 578.7 MB/s | **0.8x** | 889.7 MB/s | 4968.9 MB/s | **5.6x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 720.0 MB/s | 572.6 MB/s | **0.8x** | 900.0 MB/s | 5294.4 MB/s | **5.9x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 169.9 MB/s | 4009.1 MB/s | **23.6x** | 4088.5 MB/s | 6967.3 MB/s | **1.7x** | 2_SolidBuf_IO_and_CRC32 (90.8%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 184.4 MB/s | 174.8 MB/s | **0.9x** | 3110.0 MB/s | 1321.5 MB/s | **0.4x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 135.5 MB/s | 3960.4 MB/s | **29.2x** | 1621.8 MB/s | 6058.0 MB/s | **3.7x** | 2_SolidBuf_IO_and_CRC32 (91.3%) |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 138.6 MB/s | 184.5 MB/s | **1.3x** | 1509.1 MB/s | 1499.2 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 86.8 MB/s | 184.9 MB/s | **2.1x** | 3476.1 MB/s | 9843.4 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 65.5 MB/s | 151.0 MB/s | **2.3x** | 1444.1 MB/s | 2172.6 MB/s | **1.5x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 72.7 MB/s | 135.6 MB/s | **1.9x** | 3283.8 MB/s | 9264.6 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 61.9 MB/s | 138.5 MB/s | **2.2x** | 1664.1 MB/s | 2195.6 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4868.2 MB/s | 1283.0 MB/s | **0.3x** | 6162.6 MB/s | 5009.7 MB/s | **0.8x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 19.01 MB (19.0%) | 4893.9 MB/s | 1279.3 MB/s | **0.3x** | 6250.9 MB/s | 5846.5 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 891.0 MB/s | 76.1 MB/s | **0.1x** | 1612.6 MB/s | 5112.8 MB/s | **3.2x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 873.5 MB/s | 76.9 MB/s | **0.1x** | 1568.1 MB/s | 5164.7 MB/s | **3.3x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 4836.5 MB/s | 4343.9 MB/s | **0.9x** | 5148.8 MB/s | 1901.0 MB/s | **0.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5155.0 MB/s | 631.4 MB/s | **0.1x** | 4986.0 MB/s | 3323.0 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 662.9 MB/s | 4507.5 MB/s | **6.8x** | 3591.3 MB/s | 2010.5 MB/s | **0.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 677.9 MB/s | 648.4 MB/s | **1.0x** | 3614.1 MB/s | 3510.2 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1032.5 MB/s | 1860.2 MB/s | **1.8x** | 1745.5 MB/s | 6864.2 MB/s | **3.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1010.6 MB/s | 1862.7 MB/s | **1.8x** | 2050.1 MB/s | 7096.6 MB/s | **3.5x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.1 MB/s | 1257.4 MB/s | **13.4x** | 1654.4 MB/s | 11347.3 MB/s | **6.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 90.6 MB/s | 1239.5 MB/s | **13.7x** | 1983.1 MB/s | 10638.6 MB/s | **5.4x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 12479.8 MB/s | 1625.0 MB/s | **0.1x** | 5378.1 MB/s | 8010.4 MB/s | **1.5x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10009.9 MB/s | 1888.4 MB/s | **0.2x** | 5961.3 MB/s | 8064.3 MB/s | **1.4x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 1686.7 MB/s | 561.2 MB/s | **0.3x** | 1763.5 MB/s | 2823.1 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 1849.0 MB/s | 593.5 MB/s | **0.3x** | 1542.5 MB/s | 3031.6 MB/s | **2.0x** | - |
