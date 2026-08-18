# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 21:39:33 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 880.1 MB/s | 1940.5 MB/s | **2.2x** | 762.3 MB/s | 1300.8 MB/s | **1.7x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 876.4 MB/s | 2197.7 MB/s | **2.5x** | 559.7 MB/s | 1388.3 MB/s | **2.5x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 290.6 MB/s | 561.0 MB/s | **1.9x** | 600.6 MB/s | 1403.2 MB/s | **2.3x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 292.3 MB/s | 614.1 MB/s | **2.1x** | 490.3 MB/s | 1315.2 MB/s | **2.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 486.4 MB/s | 1198.7 MB/s | **2.5x** | 588.3 MB/s | 2067.1 MB/s | **3.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 466.7 MB/s | 888.3 MB/s | **1.9x** | 302.9 MB/s | 1884.0 MB/s | **6.2x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 384.6 MB/s | 1233.0 MB/s | **3.2x** | 596.4 MB/s | 2160.3 MB/s | **3.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 357.4 MB/s | 930.6 MB/s | **2.6x** | 289.5 MB/s | 1888.1 MB/s | **6.5x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 251.2 MB/s | 1058.7 MB/s | **4.2x** | 207.5 MB/s | 1094.9 MB/s | **5.3x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 270.5 MB/s | 1055.6 MB/s | **3.9x** | 289.6 MB/s | 1116.9 MB/s | **3.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1121.7 MB/s | 2696.6 MB/s | **2.4x** | 1420.5 MB/s | 5394.9 MB/s | **3.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 896.2 MB/s | 2945.2 MB/s | **3.3x** | 864.0 MB/s | 5485.0 MB/s | **6.3x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 303.4 MB/s | 568.3 MB/s | **1.9x** | 1014.7 MB/s | 3794.1 MB/s | **3.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 290.0 MB/s | 566.1 MB/s | **2.0x** | 687.0 MB/s | 3764.5 MB/s | **5.5x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 670.8 MB/s | 1764.1 MB/s | **2.6x** | 1001.5 MB/s | 6417.7 MB/s | **6.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 647.1 MB/s | 1597.1 MB/s | **2.5x** | 1071.4 MB/s | 4781.5 MB/s | **4.5x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 79.4 MB/s | 1246.9 MB/s | **15.7x** | 974.1 MB/s | 7020.0 MB/s | **7.2x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 79.3 MB/s | 1178.9 MB/s | **14.9x** | 991.4 MB/s | 5170.6 MB/s | **5.2x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1530.2 MB/s | 7691.4 MB/s | **5.0x** | 1508.8 MB/s | 4817.4 MB/s | **3.2x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1148.0 MB/s | 5304.7 MB/s | **4.6x** | 1366.2 MB/s | 4534.3 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 776.4 MB/s | 4507.4 MB/s | **5.8x** | 897.6 MB/s | 5289.6 MB/s | **5.9x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 770.1 MB/s | 5257.5 MB/s | **6.8x** | 910.8 MB/s | 5570.4 MB/s | **6.1x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 214.8 MB/s | 5737.7 MB/s | **26.7x** | 3983.4 MB/s | 6528.7 MB/s | **1.6x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 157.6 MB/s | 1256.9 MB/s | **8.0x** | 2272.7 MB/s | 6696.0 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 123.2 MB/s | 5682.4 MB/s | **46.1x** | 1629.4 MB/s | 6401.8 MB/s | **3.9x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 132.2 MB/s | 1350.2 MB/s | **10.2x** | 1440.8 MB/s | 6867.7 MB/s | **4.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 88.2 MB/s | 181.6 MB/s | **2.1x** | 3421.2 MB/s | 10473.2 MB/s | **3.1x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 81.8 MB/s | 172.3 MB/s | **2.1x** | 1798.8 MB/s | 2274.6 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 75.1 MB/s | 147.6 MB/s | **2.0x** | 3632.7 MB/s | 9788.1 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.7 MB/s | 140.9 MB/s | **2.0x** | 1787.2 MB/s | 2276.7 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5206.7 MB/s | 4175.4 MB/s | **0.8x** | 6141.4 MB/s | 3360.1 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 5715.6 MB/s | 5212.9 MB/s | **0.9x** | 7217.1 MB/s | 3584.2 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 1011.5 MB/s | 1781.1 MB/s | **1.8x** | 1623.1 MB/s | 5770.5 MB/s | **3.6x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 1004.1 MB/s | 1805.5 MB/s | **1.8x** | 1667.7 MB/s | 5631.5 MB/s | **3.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5616.6 MB/s | 5419.4 MB/s | **1.0x** | 5306.5 MB/s | 9317.7 MB/s | **1.8x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5432.0 MB/s | 5240.5 MB/s | **1.0x** | 4800.7 MB/s | 9727.6 MB/s | **2.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 673.2 MB/s | 4999.6 MB/s | **7.4x** | 3320.6 MB/s | 9696.8 MB/s | **2.9x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 680.6 MB/s | 4985.6 MB/s | **7.3x** | 3649.9 MB/s | 9619.4 MB/s | **2.6x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1031.3 MB/s | 1858.4 MB/s | **1.8x** | 1732.5 MB/s | 10550.7 MB/s | **6.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 991.7 MB/s | 1852.3 MB/s | **1.9x** | 1967.8 MB/s | 10483.3 MB/s | **5.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 95.4 MB/s | 1249.6 MB/s | **13.1x** | 1782.1 MB/s | 12354.2 MB/s | **6.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 96.3 MB/s | 1268.5 MB/s | **13.2x** | 2061.7 MB/s | 12128.6 MB/s | **5.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 15605.2 MB/s | 20718.4 MB/s | **1.3x** | 6016.3 MB/s | 4884.0 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 11026.8 MB/s | 22661.1 MB/s | **2.1x** | 5530.7 MB/s | 5405.0 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2181.7 MB/s | 11531.7 MB/s | **5.3x** | 1867.9 MB/s | 3218.5 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2087.6 MB/s | 11518.2 MB/s | **5.5x** | 1992.3 MB/s | 3148.7 MB/s | **1.6x** | - |
