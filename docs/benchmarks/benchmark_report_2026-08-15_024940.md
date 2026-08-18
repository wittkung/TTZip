# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 18:49:40 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 923.0 MB/s | 820.5 MB/s | **0.9x** | 685.4 MB/s | 1324.7 MB/s | **1.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 891.0 MB/s | 744.7 MB/s | **0.8x** | 517.0 MB/s | 821.0 MB/s | **1.6x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 292.5 MB/s | 408.6 MB/s | **1.4x** | 658.3 MB/s | 1279.8 MB/s | **1.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 288.8 MB/s | 428.5 MB/s | **1.5x** | 503.0 MB/s | 742.7 MB/s | **1.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 476.0 MB/s | 1276.9 MB/s | **2.7x** | 613.7 MB/s | 1881.6 MB/s | **3.1x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 435.8 MB/s | 913.3 MB/s | **2.1x** | 303.4 MB/s | 1833.8 MB/s | **6.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 386.9 MB/s | 1209.4 MB/s | **3.1x** | 604.9 MB/s | 1939.3 MB/s | **3.2x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 359.5 MB/s | 967.5 MB/s | **2.7x** | 301.6 MB/s | 1878.1 MB/s | **6.2x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 206.5 MB/s | 744.2 MB/s | **3.6x** | 275.6 MB/s | 556.9 MB/s | **2.0x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 260.9 MB/s | 956.4 MB/s | **3.7x** | 275.3 MB/s | 521.3 MB/s | **1.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1038.5 MB/s | 1634.8 MB/s | **1.6x** | 1331.4 MB/s | 3915.8 MB/s | **2.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 917.1 MB/s | 1637.6 MB/s | **1.8x** | 839.2 MB/s | 1287.9 MB/s | **1.5x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 292.9 MB/s | 546.1 MB/s | **1.9x** | 998.6 MB/s | 3705.2 MB/s | **3.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 291.9 MB/s | 549.2 MB/s | **1.9x** | 666.4 MB/s | 1243.7 MB/s | **1.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 658.0 MB/s | 1657.4 MB/s | **2.5x** | 1041.1 MB/s | 6279.3 MB/s | **6.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 653.2 MB/s | 1586.6 MB/s | **2.4x** | 1116.8 MB/s | 4798.4 MB/s | **4.3x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 77.3 MB/s | 1189.3 MB/s | **15.4x** | 944.2 MB/s | 6204.1 MB/s | **6.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 74.7 MB/s | 1116.1 MB/s | **14.9x** | 1036.7 MB/s | 5035.7 MB/s | **4.9x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1722.0 MB/s | 8197.6 MB/s | **4.8x** | 1738.9 MB/s | 5952.5 MB/s | **3.4x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1345.3 MB/s | 3876.2 MB/s | **2.9x** | 1664.3 MB/s | 5821.4 MB/s | **3.5x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 816.5 MB/s | 3243.4 MB/s | **4.0x** | 984.6 MB/s | 5667.2 MB/s | **5.8x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 823.9 MB/s | 4460.2 MB/s | **5.4x** | 967.8 MB/s | 5835.3 MB/s | **6.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 231.8 MB/s | 4788.6 MB/s | **20.7x** | 4458.4 MB/s | 7160.2 MB/s | **1.6x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 225.1 MB/s | 1202.8 MB/s | **5.3x** | 3384.0 MB/s | 5472.6 MB/s | **1.6x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 148.9 MB/s | 5173.8 MB/s | **34.7x** | 1637.0 MB/s | 6558.7 MB/s | **4.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 126.1 MB/s | 1246.0 MB/s | **9.9x** | 1275.7 MB/s | 4899.4 MB/s | **3.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 73.1 MB/s | 161.6 MB/s | **2.2x** | 3438.8 MB/s | 9442.2 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 78.7 MB/s | 163.7 MB/s | **2.1x** | 1753.6 MB/s | 2189.5 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 62.3 MB/s | 143.1 MB/s | **2.3x** | 3621.5 MB/s | 9601.8 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 68.1 MB/s | 139.7 MB/s | **2.1x** | 1724.9 MB/s | 2212.1 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5504.9 MB/s | 4046.2 MB/s | **0.7x** | 5501.2 MB/s | 6762.9 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 12.64 MB (12.6%) | 6201.7 MB/s | 13391.6 MB/s | **2.2x** | 6274.0 MB/s | 7147.2 MB/s | **1.1x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 830.5 MB/s | 1713.2 MB/s | **2.1x** | 1638.3 MB/s | 5862.4 MB/s | **3.6x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 932.2 MB/s | 1706.4 MB/s | **1.8x** | 1598.6 MB/s | 5489.5 MB/s | **3.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5409.1 MB/s | 20806.6 MB/s | **3.8x** | 5636.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5402.8 MB/s | 21171.8 MB/s | **3.9x** | 5179.6 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 655.1 MB/s | 19677.1 MB/s | **30.0x** | 3626.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 647.0 MB/s | 18038.7 MB/s | **27.9x** | 3661.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1023.6 MB/s | 1844.4 MB/s | **1.8x** | 1745.1 MB/s | 6995.0 MB/s | **4.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 995.0 MB/s | 1845.6 MB/s | **1.9x** | 2090.4 MB/s | 7608.1 MB/s | **3.6x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.2 MB/s | 1228.1 MB/s | **13.2x** | 1730.0 MB/s | 11730.3 MB/s | **6.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.7 MB/s | 1214.2 MB/s | **12.8x** | 1958.6 MB/s | 12049.6 MB/s | **6.2x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 15120.2 MB/s | 17870.7 MB/s | **1.2x** | 5994.3 MB/s | 8299.7 MB/s | **1.4x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 11220.6 MB/s | 19382.3 MB/s | **1.7x** | 6276.8 MB/s | 9010.0 MB/s | **1.4x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2071.9 MB/s | 10872.4 MB/s | **5.2x** | 1936.8 MB/s | 3198.9 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2034.1 MB/s | 10563.0 MB/s | **5.2x** | 1908.9 MB/s | 3201.5 MB/s | **1.7x** | - |
