# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 18:52:12 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 864.4 MB/s | 709.8 MB/s | **0.8x** | 726.3 MB/s | 1398.4 MB/s | **1.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 861.9 MB/s | 829.2 MB/s | **1.0x** | 559.5 MB/s | 814.1 MB/s | **1.5x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 287.6 MB/s | 408.1 MB/s | **1.4x** | 618.3 MB/s | 1204.2 MB/s | **1.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 283.8 MB/s | 416.0 MB/s | **1.5x** | 480.1 MB/s | 760.7 MB/s | **1.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 464.1 MB/s | 1215.0 MB/s | **2.6x** | 582.5 MB/s | 2147.1 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 434.6 MB/s | 870.4 MB/s | **2.0x** | 292.9 MB/s | 1801.9 MB/s | **6.2x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 378.8 MB/s | 1282.7 MB/s | **3.4x** | 584.6 MB/s | 2231.9 MB/s | **3.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 345.2 MB/s | 895.2 MB/s | **2.6x** | 292.4 MB/s | 1958.8 MB/s | **6.7x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 254.6 MB/s | 1064.0 MB/s | **4.2x** | 276.0 MB/s | 947.9 MB/s | **3.4x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 285.4 MB/s | 1023.7 MB/s | **3.6x** | 275.9 MB/s | 983.6 MB/s | **3.6x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1037.1 MB/s | 2447.5 MB/s | **2.4x** | 1388.6 MB/s | 4779.5 MB/s | **3.4x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 925.0 MB/s | 1557.9 MB/s | **1.7x** | 819.5 MB/s | 1332.0 MB/s | **1.6x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 289.5 MB/s | 522.6 MB/s | **1.8x** | 916.0 MB/s | 3728.0 MB/s | **4.1x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 288.5 MB/s | 526.8 MB/s | **1.8x** | 658.1 MB/s | 1190.8 MB/s | **1.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 654.4 MB/s | 1638.6 MB/s | **2.5x** | 939.3 MB/s | 6095.2 MB/s | **6.5x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 638.0 MB/s | 1554.1 MB/s | **2.4x** | 1009.2 MB/s | 4445.6 MB/s | **4.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 76.5 MB/s | 1196.6 MB/s | **15.7x** | 930.3 MB/s | 5570.8 MB/s | **6.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 75.8 MB/s | 1117.6 MB/s | **14.7x** | 1017.6 MB/s | 4854.5 MB/s | **4.8x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1699.0 MB/s | 6798.1 MB/s | **4.0x** | 1606.4 MB/s | 5618.1 MB/s | **3.5x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1279.5 MB/s | 4219.2 MB/s | **3.3x** | 1544.4 MB/s | 5572.0 MB/s | **3.6x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 633.0 MB/s | 4885.1 MB/s | **7.7x** | 663.7 MB/s | 5322.6 MB/s | **8.0x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 722.9 MB/s | 4920.9 MB/s | **6.8x** | 928.1 MB/s | 5092.8 MB/s | **5.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 207.9 MB/s | 4496.4 MB/s | **21.6x** | 4381.8 MB/s | 6309.0 MB/s | **1.4x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 220.7 MB/s | 1197.0 MB/s | **5.4x** | 3243.3 MB/s | 4658.8 MB/s | **1.4x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 143.7 MB/s | 5033.4 MB/s | **35.0x** | 1712.4 MB/s | 6747.0 MB/s | **3.9x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 137.9 MB/s | 1220.2 MB/s | **8.9x** | 1539.0 MB/s | 4670.1 MB/s | **3.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 87.7 MB/s | 177.3 MB/s | **2.0x** | 3956.2 MB/s | 10644.8 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 82.9 MB/s | 168.9 MB/s | **2.0x** | 1839.5 MB/s | 2308.3 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 73.9 MB/s | 146.8 MB/s | **2.0x** | 3773.5 MB/s | 10499.9 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.1 MB/s | 140.6 MB/s | **2.0x** | 1829.5 MB/s | 2290.3 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5694.2 MB/s | 4812.6 MB/s | **0.8x** | 6077.7 MB/s | 6845.3 MB/s | **1.1x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 5774.7 MB/s | 4778.9 MB/s | **0.8x** | 7217.0 MB/s | 6060.2 MB/s | **0.8x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 443.3 MB/s | 1761.9 MB/s | **4.0x** | 1078.5 MB/s | 3786.5 MB/s | **3.5x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 880.1 MB/s | 1336.5 MB/s | **1.5x** | 1610.4 MB/s | 5150.1 MB/s | **3.2x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.10 MB (0.0%) | 5547.0 MB/s | 21291.0 MB/s | **3.8x** | 5327.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.10 MB (0.0%) | 5344.4 MB/s | 20242.0 MB/s | **3.8x** | 5280.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 680.5 MB/s | 18915.6 MB/s | **27.8x** | 3411.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 676.3 MB/s | 19884.0 MB/s | **29.4x** | 3637.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1041.0 MB/s | 1776.4 MB/s | **1.7x** | 1753.1 MB/s | 6878.3 MB/s | **3.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1032.4 MB/s | 1844.9 MB/s | **1.8x** | 1866.5 MB/s | 7431.7 MB/s | **4.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 90.7 MB/s | 1259.9 MB/s | **13.9x** | 1694.2 MB/s | 11791.2 MB/s | **7.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 92.6 MB/s | 1122.0 MB/s | **12.1x** | 1950.8 MB/s | 8661.4 MB/s | **4.4x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 15175.4 MB/s | 21522.3 MB/s | **1.4x** | 6274.6 MB/s | 8120.0 MB/s | **1.3x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 9723.0 MB/s | 21925.5 MB/s | **2.3x** | 6436.7 MB/s | 8524.2 MB/s | **1.3x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2069.6 MB/s | 10409.5 MB/s | **5.0x** | 1879.6 MB/s | 3064.6 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2022.6 MB/s | 10722.0 MB/s | **5.3x** | 1758.6 MB/s | 3160.5 MB/s | **1.8x** | - |
