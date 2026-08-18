# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-13 16:55:32 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 844.1 MB/s | 426.1 MB/s | **0.5x** | 746.6 MB/s | 624.8 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 821.1 MB/s | 243.5 MB/s | **0.3x** | 569.0 MB/s | 471.2 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 293.2 MB/s | 438.3 MB/s | **1.5x** | 626.4 MB/s | 714.8 MB/s | **1.1x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 291.1 MB/s | 245.6 MB/s | **0.8x** | 456.9 MB/s | 456.6 MB/s | **1.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 467.1 MB/s | 661.0 MB/s | **1.4x** | 586.2 MB/s | 1895.9 MB/s | **3.2x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 464.3 MB/s | 539.0 MB/s | **1.2x** | 299.8 MB/s | 252.3 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 393.4 MB/s | 663.2 MB/s | **1.7x** | 598.8 MB/s | 2063.9 MB/s | **3.4x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 354.8 MB/s | 518.0 MB/s | **1.5x** | 297.7 MB/s | 235.3 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 297.3 MB/s | 361.8 MB/s | **1.2x** | 270.8 MB/s | 955.6 MB/s | **3.5x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 293.0 MB/s | 395.9 MB/s | **1.4x** | 268.2 MB/s | 882.4 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1050.8 MB/s | 541.6 MB/s | **0.5x** | 1318.9 MB/s | 1860.4 MB/s | **1.4x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 906.9 MB/s | 299.0 MB/s | **0.3x** | 819.9 MB/s | 637.7 MB/s | **0.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 298.6 MB/s | 528.8 MB/s | **1.8x** | 944.4 MB/s | 1855.4 MB/s | **2.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 292.6 MB/s | 291.1 MB/s | **1.0x** | 637.6 MB/s | 628.3 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 639.7 MB/s | 1031.5 MB/s | **1.6x** | 966.0 MB/s | 6235.8 MB/s | **6.5x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 635.2 MB/s | 1012.8 MB/s | **1.6x** | 1027.1 MB/s | 749.3 MB/s | **0.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 73.5 MB/s | 836.2 MB/s | **11.4x** | 941.7 MB/s | 6922.0 MB/s | **7.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 74.8 MB/s | 826.5 MB/s | **11.1x** | 999.6 MB/s | 762.8 MB/s | **0.8x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1672.4 MB/s | 1853.7 MB/s | **1.1x** | 1569.6 MB/s | 6080.0 MB/s | **3.9x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1289.7 MB/s | 1450.6 MB/s | **1.1x** | 1513.3 MB/s | 5497.4 MB/s | **3.6x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.3%) | 799.6 MB/s | 577.2 MB/s | **0.7x** | 910.1 MB/s | 5514.9 MB/s | **6.1x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 782.4 MB/s | 579.5 MB/s | **0.7x** | 928.5 MB/s | 5690.1 MB/s | **6.1x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 161.2 MB/s | 2547.5 MB/s | **15.8x** | 3833.2 MB/s | 6600.3 MB/s | **1.7x** | 2_SolidBuf_IO_and_CRC32 (96.3%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 189.6 MB/s | 175.0 MB/s | **0.9x** | 3311.4 MB/s | 1399.1 MB/s | **0.4x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 140.8 MB/s | 2532.5 MB/s | **18.0x** | 1652.0 MB/s | 6400.7 MB/s | **3.9x** | 2_SolidBuf_IO_and_CRC32 (96.7%) |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 139.4 MB/s | 191.3 MB/s | **1.4x** | 1380.6 MB/s | 1432.0 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 85.3 MB/s | 1750.5 MB/s | **20.5x** | 3443.8 MB/s | 10220.5 MB/s | **3.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.8 MB/s | 856.7 MB/s | **12.1x** | 1646.0 MB/s | 795.2 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 72.6 MB/s | 1697.0 MB/s | **23.4x** | 2968.7 MB/s | 6705.8 MB/s | **2.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 68.2 MB/s | 1014.3 MB/s | **14.9x** | 1769.6 MB/s | 868.3 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5874.2 MB/s | 1316.4 MB/s | **0.2x** | 5235.8 MB/s | 6233.3 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 6068.6 MB/s | 1489.4 MB/s | **0.2x** | 7136.9 MB/s | 8693.3 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 905.5 MB/s | 75.5 MB/s | **0.1x** | 1661.5 MB/s | 4985.1 MB/s | **3.0x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 872.5 MB/s | 76.4 MB/s | **0.1x** | 1653.4 MB/s | 5295.3 MB/s | **3.2x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 4917.5 MB/s | 3151.4 MB/s | **0.6x** | 5140.6 MB/s | 2059.8 MB/s | **0.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4881.7 MB/s | 660.1 MB/s | **0.1x** | 4901.3 MB/s | 3555.9 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 653.3 MB/s | 3119.1 MB/s | **4.8x** | 3610.0 MB/s | 2034.8 MB/s | **0.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 662.8 MB/s | 653.0 MB/s | **1.0x** | 3486.0 MB/s | 3488.4 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 991.1 MB/s | 561.0 MB/s | **0.6x** | 1695.3 MB/s | 6827.9 MB/s | **4.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1021.5 MB/s | 559.0 MB/s | **0.5x** | 2064.9 MB/s | 1464.5 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.7 MB/s | 490.1 MB/s | **5.2x** | 1734.0 MB/s | 11535.6 MB/s | **6.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 95.2 MB/s | 506.2 MB/s | **5.3x** | 2039.7 MB/s | 1533.1 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 14182.9 MB/s | 1880.7 MB/s | **0.1x** | 5892.0 MB/s | 7664.3 MB/s | **1.3x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 9777.2 MB/s | 1316.2 MB/s | **0.1x** | 6335.5 MB/s | 9874.9 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 2168.1 MB/s | 598.7 MB/s | **0.3x** | 1739.9 MB/s | 3164.0 MB/s | **1.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 2031.9 MB/s | 596.9 MB/s | **0.3x** | 1879.2 MB/s | 3148.1 MB/s | **1.7x** | - |
