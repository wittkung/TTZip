# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 19:03:51 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 263.6 MB/s | 555.6 MB/s | **2.1x** | 373.2 MB/s | 378.6 MB/s | **1.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 598.2 MB/s | 549.9 MB/s | **0.9x** | 439.3 MB/s | 569.3 MB/s | **1.3x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 248.0 MB/s | 298.6 MB/s | **1.2x** | 519.0 MB/s | 906.8 MB/s | **1.7x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 257.6 MB/s | 351.9 MB/s | **1.4x** | 408.5 MB/s | 687.0 MB/s | **1.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 431.1 MB/s | 965.8 MB/s | **2.2x** | 551.8 MB/s | 1954.5 MB/s | **3.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 426.9 MB/s | 835.6 MB/s | **2.0x** | 277.6 MB/s | 1759.5 MB/s | **6.3x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 398.1 MB/s | 1162.5 MB/s | **2.9x** | 596.0 MB/s | 1994.5 MB/s | **3.3x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 380.9 MB/s | 900.5 MB/s | **2.4x** | 313.3 MB/s | 1689.6 MB/s | **5.4x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 254.2 MB/s | 985.6 MB/s | **3.9x** | 254.8 MB/s | 744.5 MB/s | **2.9x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 261.8 MB/s | 1042.8 MB/s | **4.0x** | 194.9 MB/s | 734.4 MB/s | **3.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1036.4 MB/s | 2831.6 MB/s | **2.7x** | 1006.9 MB/s | 4902.3 MB/s | **4.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 888.1 MB/s | 1302.3 MB/s | **1.5x** | 838.4 MB/s | 1253.4 MB/s | **1.5x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 288.2 MB/s | 489.0 MB/s | **1.7x** | 992.5 MB/s | 3495.2 MB/s | **3.5x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 287.2 MB/s | 548.0 MB/s | **1.9x** | 700.8 MB/s | 1240.1 MB/s | **1.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 683.6 MB/s | 1789.1 MB/s | **2.6x** | 1058.7 MB/s | 6094.5 MB/s | **5.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 670.4 MB/s | 1657.5 MB/s | **2.5x** | 1128.2 MB/s | 4529.7 MB/s | **4.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 79.3 MB/s | 1296.8 MB/s | **16.3x** | 965.5 MB/s | 6209.5 MB/s | **6.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 79.9 MB/s | 1076.0 MB/s | **13.5x** | 970.1 MB/s | 5198.8 MB/s | **5.4x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1780.4 MB/s | 6672.4 MB/s | **3.7x** | 1810.4 MB/s | 4701.4 MB/s | **2.6x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1358.9 MB/s | 4038.8 MB/s | **3.0x** | 1650.3 MB/s | 5120.7 MB/s | **3.1x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 801.3 MB/s | 3925.3 MB/s | **4.9x** | 980.9 MB/s | 5656.8 MB/s | **5.8x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 822.7 MB/s | 5011.2 MB/s | **6.1x** | 940.9 MB/s | 5878.4 MB/s | **6.2x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 234.7 MB/s | 4778.3 MB/s | **20.4x** | 4417.5 MB/s | 5920.1 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 239.1 MB/s | 1229.9 MB/s | **5.1x** | 3387.7 MB/s | 4331.6 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 148.2 MB/s | 5071.2 MB/s | **34.2x** | 1692.3 MB/s | 6558.6 MB/s | **3.9x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 144.1 MB/s | 1224.2 MB/s | **8.5x** | 1473.8 MB/s | 4902.8 MB/s | **3.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 89.0 MB/s | 189.8 MB/s | **2.1x** | 3814.1 MB/s | 11229.5 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 83.5 MB/s | 180.1 MB/s | **2.2x** | 1945.6 MB/s | 2327.0 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 77.2 MB/s | 150.5 MB/s | **1.9x** | 3929.2 MB/s | 11471.1 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 68.9 MB/s | 144.1 MB/s | **2.1x** | 1903.3 MB/s | 2347.2 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 6169.6 MB/s | 3965.6 MB/s | **0.6x** | 6556.9 MB/s | 4742.1 MB/s | **0.7x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 10.01 MB (10.0%) | 5650.4 MB/s | 13170.9 MB/s | **2.3x** | 5750.9 MB/s | 5799.2 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 826.3 MB/s | 1610.6 MB/s | **1.9x** | 1581.8 MB/s | 4907.7 MB/s | **3.1x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 801.6 MB/s | 1497.1 MB/s | **1.9x** | 1400.1 MB/s | 5101.2 MB/s | **3.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.10 MB (0.0%) | 5319.9 MB/s | 18537.3 MB/s | **3.5x** | 5502.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.10 MB (0.0%) | 5179.0 MB/s | 20894.1 MB/s | **4.0x** | 4998.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 667.3 MB/s | 16765.5 MB/s | **25.1x** | 3784.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 594.1 MB/s | 13304.8 MB/s | **22.4x** | 3438.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 999.5 MB/s | 1833.9 MB/s | **1.8x** | 1747.3 MB/s | 6749.4 MB/s | **3.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1008.2 MB/s | 1867.3 MB/s | **1.9x** | 1799.3 MB/s | 7512.1 MB/s | **4.2x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 95.5 MB/s | 1217.5 MB/s | **12.8x** | 1370.9 MB/s | 11533.1 MB/s | **8.4x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 92.9 MB/s | 1240.2 MB/s | **13.3x** | 2003.5 MB/s | 11683.6 MB/s | **5.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 14306.9 MB/s | 15891.2 MB/s | **1.1x** | 5770.3 MB/s | 5189.8 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 11145.1 MB/s | 15303.3 MB/s | **1.4x** | 6231.6 MB/s | 5240.1 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 1969.4 MB/s | 9157.9 MB/s | **4.7x** | 1906.2 MB/s | 3091.1 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 1978.3 MB/s | 9562.1 MB/s | **4.8x** | 1896.6 MB/s | 3215.7 MB/s | **1.7x** | - |
