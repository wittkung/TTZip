# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 21:08:03 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 855.3 MB/s | 929.9 MB/s | **1.1x** | 673.6 MB/s | 1307.5 MB/s | **1.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 811.2 MB/s | 890.7 MB/s | **1.1x** | 551.4 MB/s | 1343.5 MB/s | **2.4x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 287.4 MB/s | 419.1 MB/s | **1.5x** | 587.7 MB/s | 1335.8 MB/s | **2.3x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 287.4 MB/s | 428.9 MB/s | **1.5x** | 477.0 MB/s | 1327.8 MB/s | **2.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 445.7 MB/s | 1230.5 MB/s | **2.8x** | 552.1 MB/s | 2081.0 MB/s | **3.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 419.2 MB/s | 888.2 MB/s | **2.1x** | 296.0 MB/s | 1899.8 MB/s | **6.4x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 383.0 MB/s | 1261.4 MB/s | **3.3x** | 576.1 MB/s | 2179.9 MB/s | **3.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 371.7 MB/s | 933.6 MB/s | **2.5x** | 294.2 MB/s | 1871.1 MB/s | **6.4x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 286.6 MB/s | 1064.0 MB/s | **3.7x** | 277.5 MB/s | 1095.9 MB/s | **3.9x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 294.7 MB/s | 1056.4 MB/s | **3.6x** | 283.2 MB/s | 1088.6 MB/s | **3.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1111.5 MB/s | 2636.3 MB/s | **2.4x** | 1382.5 MB/s | 5236.9 MB/s | **3.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 934.1 MB/s | 2789.7 MB/s | **3.0x** | 836.0 MB/s | 5567.0 MB/s | **6.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 296.3 MB/s | 565.1 MB/s | **1.9x** | 961.3 MB/s | 3939.0 MB/s | **4.1x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 293.6 MB/s | 539.0 MB/s | **1.8x** | 674.2 MB/s | 4049.6 MB/s | **6.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 661.9 MB/s | 1813.1 MB/s | **2.7x** | 963.7 MB/s | 6488.3 MB/s | **6.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 643.7 MB/s | 1638.5 MB/s | **2.5x** | 1037.7 MB/s | 4897.3 MB/s | **4.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 78.5 MB/s | 1266.4 MB/s | **16.1x** | 962.8 MB/s | 7390.6 MB/s | **7.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 77.0 MB/s | 1183.8 MB/s | **15.4x** | 1049.7 MB/s | 5450.7 MB/s | **5.2x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1677.9 MB/s | 8168.6 MB/s | **4.9x** | 1732.1 MB/s | 5366.9 MB/s | **3.1x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1270.6 MB/s | 6086.7 MB/s | **4.8x** | 1608.8 MB/s | 5318.9 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 810.5 MB/s | 4727.6 MB/s | **5.8x** | 932.6 MB/s | 5931.6 MB/s | **6.4x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 800.1 MB/s | 4663.2 MB/s | **5.8x** | 919.4 MB/s | 5802.6 MB/s | **6.3x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 228.2 MB/s | 5434.0 MB/s | **23.8x** | 4122.0 MB/s | 6531.7 MB/s | **1.6x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 229.6 MB/s | 1326.3 MB/s | **5.8x** | 3236.6 MB/s | 8103.2 MB/s | **2.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 144.5 MB/s | 5213.2 MB/s | **36.1x** | 1661.0 MB/s | 6650.9 MB/s | **4.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 145.3 MB/s | 1359.9 MB/s | **9.4x** | 1543.6 MB/s | 7732.6 MB/s | **5.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 90.1 MB/s | 180.8 MB/s | **2.0x** | 3934.0 MB/s | 11484.4 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 79.9 MB/s | 175.4 MB/s | **2.2x** | 1749.3 MB/s | 2336.2 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 75.4 MB/s | 147.0 MB/s | **1.9x** | 3733.6 MB/s | 10394.2 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.2 MB/s | 140.2 MB/s | **2.0x** | 1839.8 MB/s | 2364.8 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5940.9 MB/s | 5049.6 MB/s | **0.8x** | 6760.5 MB/s | 3500.3 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 5884.9 MB/s | 5298.5 MB/s | **0.9x** | 6625.3 MB/s | 4550.5 MB/s | **0.7x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 963.1 MB/s | 1808.9 MB/s | **1.9x** | 1624.0 MB/s | 5712.9 MB/s | **3.5x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 987.5 MB/s | 1784.0 MB/s | **1.8x** | 1635.7 MB/s | 5517.3 MB/s | **3.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5245.3 MB/s | 4957.4 MB/s | **0.9x** | 5399.1 MB/s | 8943.3 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5347.5 MB/s | 5060.7 MB/s | **0.9x** | 4982.4 MB/s | 9597.8 MB/s | **1.9x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 687.2 MB/s | 4777.7 MB/s | **7.0x** | 3419.6 MB/s | 9763.7 MB/s | **2.9x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 679.5 MB/s | 4823.0 MB/s | **7.1x** | 3510.8 MB/s | 9843.4 MB/s | **2.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1011.7 MB/s | 1862.6 MB/s | **1.8x** | 1740.5 MB/s | 10473.0 MB/s | **6.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1025.4 MB/s | 1841.4 MB/s | **1.8x** | 2058.5 MB/s | 10586.5 MB/s | **5.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.1 MB/s | 1251.7 MB/s | **13.3x** | 1759.9 MB/s | 12194.7 MB/s | **6.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.6 MB/s | 1246.1 MB/s | **13.2x** | 1976.0 MB/s | 11650.6 MB/s | **5.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 15367.4 MB/s | 19010.4 MB/s | **1.2x** | 5264.0 MB/s | 4852.1 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 11431.8 MB/s | 22240.4 MB/s | **1.9x** | 5879.2 MB/s | 4851.6 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2121.3 MB/s | 10999.3 MB/s | **5.2x** | 1859.3 MB/s | 3228.8 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2066.1 MB/s | 11122.6 MB/s | **5.4x** | 1986.3 MB/s | 3188.5 MB/s | **1.6x** | - |
