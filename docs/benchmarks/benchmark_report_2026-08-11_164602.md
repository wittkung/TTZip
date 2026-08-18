# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-11 08:46:02 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 952.1 MB/s | 285.9 MB/s | **0.3x** | 712.8 MB/s | 563.3 MB/s | **0.8x** |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 926.5 MB/s | 284.2 MB/s | **0.3x** | 556.0 MB/s | 477.1 MB/s | **0.9x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 284.1 MB/s | 289.1 MB/s | **1.0x** | 628.2 MB/s | 605.9 MB/s | **1.0x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 284.5 MB/s | 285.8 MB/s | **1.0x** | 485.6 MB/s | 476.1 MB/s | **1.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 415.4 MB/s | 6199.0 MB/s | **14.9x** | 599.0 MB/s | 2213.5 MB/s | **3.7x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 400.6 MB/s | 2225.8 MB/s | **5.6x** | 306.7 MB/s | 1891.8 MB/s | **6.2x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 342.1 MB/s | 8013.7 MB/s | **23.4x** | 597.1 MB/s | 1985.3 MB/s | **3.3x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 319.4 MB/s | 2202.5 MB/s | **6.9x** | 307.5 MB/s | 1812.4 MB/s | **5.9x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 260.9 MB/s | 568.8 MB/s | **2.2x** | 269.9 MB/s | 941.2 MB/s | **3.5x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 262.6 MB/s | 572.7 MB/s | **2.2x** | 267.1 MB/s | 944.0 MB/s | **3.5x** |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1184.7 MB/s | 283.5 MB/s | **0.2x** | 1444.3 MB/s | 961.3 MB/s | **0.7x** |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1007.5 MB/s | 283.0 MB/s | **0.3x** | 851.2 MB/s | 663.6 MB/s | **0.8x** |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 287.6 MB/s | 286.8 MB/s | **1.0x** | 1008.8 MB/s | 962.6 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 282.0 MB/s | 266.3 MB/s | **0.9x** | 680.1 MB/s | 532.5 MB/s | **0.8x** |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 715.9 MB/s | 1713.9 MB/s | **2.4x** | 1016.9 MB/s | 5336.3 MB/s | **5.2x** |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 697.1 MB/s | 1550.3 MB/s | **2.2x** | 1104.4 MB/s | 4646.3 MB/s | **4.2x** |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 81.5 MB/s | 1247.5 MB/s | **15.3x** | 973.7 MB/s | 6463.2 MB/s | **6.6x** |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 81.0 MB/s | 1179.7 MB/s | **14.6x** | 1030.8 MB/s | 4784.2 MB/s | **4.6x** |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 680.4 MB/s | 1633.2 MB/s | **2.4x** | 1608.0 MB/s | 6085.5 MB/s | **3.8x** |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1252.5 MB/s | 1454.6 MB/s | **1.2x** | 1619.3 MB/s | 6173.3 MB/s | **3.8x** |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.3%) | 758.6 MB/s | 628.7 MB/s | **0.8x** | 921.3 MB/s | 3159.5 MB/s | **3.4x** |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 751.8 MB/s | 630.0 MB/s | **0.8x** | 920.2 MB/s | 4966.5 MB/s | **5.4x** |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 229.4 MB/s | 180.2 MB/s | **0.8x** | 3873.9 MB/s | 1510.9 MB/s | **0.4x** |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 228.4 MB/s | 177.2 MB/s | **0.8x** | 3113.1 MB/s | 1464.6 MB/s | **0.5x** |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 143.2 MB/s | 184.0 MB/s | **1.3x** | 1627.2 MB/s | 1623.8 MB/s | **1.0x** |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 142.0 MB/s | 177.8 MB/s | **1.3x** | 1484.8 MB/s | 1448.1 MB/s | **1.0x** |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 90.3 MB/s | 199.3 MB/s | **2.2x** | 3557.1 MB/s | 6094.0 MB/s | **1.7x** |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 83.4 MB/s | 183.2 MB/s | **2.2x** | 1791.4 MB/s | 2163.4 MB/s | **1.2x** |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 74.7 MB/s | 156.1 MB/s | **2.1x** | 3538.7 MB/s | 7616.1 MB/s | **2.2x** |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 68.3 MB/s | 147.9 MB/s | **2.2x** | 1658.6 MB/s | 2096.7 MB/s | **1.3x** |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4405.4 MB/s | 1329.5 MB/s | **0.3x** | 6387.6 MB/s | 4673.4 MB/s | **0.7x** |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 5059.7 MB/s | 1081.9 MB/s | **0.2x** | 4743.3 MB/s | 6144.8 MB/s | **1.3x** |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 775.6 MB/s | 71.7 MB/s | **0.1x** | 811.0 MB/s | 3376.0 MB/s | **4.2x** |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 732.9 MB/s | 70.4 MB/s | **0.1x** | 665.6 MB/s | 3639.3 MB/s | **5.5x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4751.9 MB/s | 635.2 MB/s | **0.1x** | 4935.9 MB/s | 3469.5 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4833.0 MB/s | 632.7 MB/s | **0.1x** | 4712.9 MB/s | 3354.1 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 653.3 MB/s | 633.0 MB/s | **1.0x** | 3566.1 MB/s | 2954.3 MB/s | **0.8x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 659.8 MB/s | 636.6 MB/s | **1.0x** | 3458.6 MB/s | 2737.7 MB/s | **0.8x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1000.0 MB/s | 1614.7 MB/s | **1.6x** | 1668.3 MB/s | 5823.6 MB/s | **3.5x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1001.9 MB/s | 1587.2 MB/s | **1.6x** | 1965.5 MB/s | 6468.9 MB/s | **3.3x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.9 MB/s | 1134.5 MB/s | **12.1x** | 1694.4 MB/s | 9955.0 MB/s | **5.9x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 97.2 MB/s | 1141.4 MB/s | **11.7x** | 2057.9 MB/s | 10155.4 MB/s | **4.9x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 11598.1 MB/s | 1809.6 MB/s | **0.2x** | 5369.6 MB/s | 5646.9 MB/s | **1.1x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 9174.1 MB/s | 1296.4 MB/s | **0.1x** | 6213.6 MB/s | 8836.1 MB/s | **1.4x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 2165.7 MB/s | 611.3 MB/s | **0.3x** | 1798.6 MB/s | 3103.0 MB/s | **1.7x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 2062.1 MB/s | 610.2 MB/s | **0.3x** | 1968.8 MB/s | 3100.1 MB/s | **1.6x** |
