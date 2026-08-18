# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-11 08:14:07 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 977.9 MB/s | 289.3 MB/s | **0.3x** | 794.9 MB/s | 632.1 MB/s | **0.8x** |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 906.6 MB/s | 286.1 MB/s | **0.3x** | 584.8 MB/s | 498.7 MB/s | **0.9x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 288.9 MB/s | 287.4 MB/s | **1.0x** | 651.9 MB/s | 636.5 MB/s | **1.0x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 284.2 MB/s | 284.8 MB/s | **1.0x** | 505.3 MB/s | 495.5 MB/s | **1.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 413.5 MB/s | 8381.5 MB/s | **20.3x** | 617.6 MB/s | 1704.4 MB/s | **2.8x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 388.7 MB/s | 2347.4 MB/s | **6.0x** | 304.9 MB/s | 1813.6 MB/s | **5.9x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 340.8 MB/s | 7583.9 MB/s | **22.3x** | 609.1 MB/s | 1832.0 MB/s | **3.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 348.6 MB/s | 2369.6 MB/s | **6.8x** | 303.5 MB/s | 1968.1 MB/s | **6.5x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.07 MB (0.6%) | 304.6 MB/s | 236.4 MB/s | **0.8x** | 279.6 MB/s | 355.4 MB/s | **1.3x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.07 MB (0.6%) | 309.1 MB/s | 232.6 MB/s | **0.8x** | 273.7 MB/s | 347.7 MB/s | **1.3x** |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1035.8 MB/s | 282.0 MB/s | **0.3x** | 1253.0 MB/s | 893.9 MB/s | **0.7x** |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 870.2 MB/s | 283.5 MB/s | **0.3x** | 742.1 MB/s | 594.4 MB/s | **0.8x** |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 287.3 MB/s | 285.1 MB/s | **1.0x** | 935.3 MB/s | 913.2 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 282.6 MB/s | 284.7 MB/s | **1.0x** | 611.5 MB/s | 596.1 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 691.9 MB/s | 1727.1 MB/s | **2.5x** | 964.7 MB/s | 4848.0 MB/s | **5.0x** |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 656.6 MB/s | 1158.0 MB/s | **1.8x** | 1000.4 MB/s | 2968.0 MB/s | **3.0x** |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 87.3 MB/s | 1236.1 MB/s | **14.2x** | 883.5 MB/s | 5794.6 MB/s | **6.6x** |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 86.2 MB/s | 1158.4 MB/s | **13.4x** | 942.0 MB/s | 3556.6 MB/s | **3.8x** |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1448.3 MB/s | 1052.0 MB/s | **0.7x** | 1533.7 MB/s | 1247.2 MB/s | **0.8x** |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1107.7 MB/s | 889.7 MB/s | **0.8x** | 1427.5 MB/s | 1228.5 MB/s | **0.9x** |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.7%) | 0.03 MB (0.3%) | 705.6 MB/s | 490.3 MB/s | **0.7x** | 863.9 MB/s | 2056.4 MB/s | **2.4x** |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 690.6 MB/s | 488.0 MB/s | **0.7x** | 818.8 MB/s | 2150.2 MB/s | **2.6x** |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 233.6 MB/s | 183.4 MB/s | **0.8x** | 3993.5 MB/s | 1578.2 MB/s | **0.4x** |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 229.5 MB/s | 180.2 MB/s | **0.8x** | 3139.7 MB/s | 1416.3 MB/s | **0.5x** |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 143.3 MB/s | 186.0 MB/s | **1.3x** | 1666.6 MB/s | 1571.2 MB/s | **0.9x** |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 141.3 MB/s | 183.9 MB/s | **1.3x** | 1494.2 MB/s | 1510.9 MB/s | **1.0x** |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 90.0 MB/s | 189.7 MB/s | **2.1x** | 3543.7 MB/s | 7215.1 MB/s | **2.0x** |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 82.7 MB/s | 184.4 MB/s | **2.2x** | 1766.6 MB/s | 2146.0 MB/s | **1.2x** |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 73.9 MB/s | 153.7 MB/s | **2.1x** | 3463.4 MB/s | 6770.9 MB/s | **2.0x** |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 68.9 MB/s | 101.8 MB/s | **1.5x** | 1692.8 MB/s | 1890.3 MB/s | **1.1x** |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4533.1 MB/s | 1233.5 MB/s | **0.3x** | 5833.4 MB/s | 1473.6 MB/s | **0.3x** |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 4935.7 MB/s | 1205.3 MB/s | **0.2x** | 4567.2 MB/s | 3382.1 MB/s | **0.7x** |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 866.5 MB/s | 76.0 MB/s | **0.1x** | 1568.6 MB/s | 3389.4 MB/s | **2.2x** |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 844.9 MB/s | 77.5 MB/s | **0.1x** | 1541.2 MB/s | 3379.5 MB/s | **2.2x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4897.9 MB/s | 627.6 MB/s | **0.1x** | 5200.9 MB/s | 3165.0 MB/s | **0.6x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4905.0 MB/s | 616.0 MB/s | **0.1x** | 4914.3 MB/s | 3286.2 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 650.7 MB/s | 629.0 MB/s | **1.0x** | 3603.8 MB/s | 3154.3 MB/s | **0.9x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 636.5 MB/s | 620.5 MB/s | **1.0x** | 3435.1 MB/s | 3354.7 MB/s | **1.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1002.2 MB/s | 1601.0 MB/s | **1.6x** | 1683.1 MB/s | 5956.6 MB/s | **3.5x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 990.1 MB/s | 1546.0 MB/s | **1.6x** | 1965.8 MB/s | 6018.6 MB/s | **3.1x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.8 MB/s | 1141.1 MB/s | **12.2x** | 1673.0 MB/s | 10353.8 MB/s | **6.2x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.5 MB/s | 1129.7 MB/s | **12.1x** | 1989.3 MB/s | 10156.6 MB/s | **5.1x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10205.7 MB/s | 1239.0 MB/s | **0.1x** | 4922.9 MB/s | 4996.9 MB/s | **1.0x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 8786.6 MB/s | 1142.5 MB/s | **0.1x** | 5780.4 MB/s | 5742.4 MB/s | **1.0x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 2006.3 MB/s | 579.8 MB/s | **0.3x** | 1772.0 MB/s | 2990.1 MB/s | **1.7x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 1895.1 MB/s | 558.3 MB/s | **0.3x** | 1786.1 MB/s | 3023.4 MB/s | **1.7x** |
