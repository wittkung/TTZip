# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 22:03:29 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 757.8 MB/s | 1810.2 MB/s | **2.4x** | 618.8 MB/s | 1417.6 MB/s | **2.3x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 821.8 MB/s | 2224.2 MB/s | **2.7x** | 534.9 MB/s | 1520.6 MB/s | **2.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 275.4 MB/s | 536.9 MB/s | **1.9x** | 577.1 MB/s | 1335.3 MB/s | **2.3x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 277.8 MB/s | 552.3 MB/s | **2.0x** | 461.6 MB/s | 1333.2 MB/s | **2.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 405.5 MB/s | 1171.9 MB/s | **2.9x** | 537.8 MB/s | 2029.7 MB/s | **3.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 375.4 MB/s | 871.2 MB/s | **2.3x** | 281.9 MB/s | 1848.6 MB/s | **6.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 346.9 MB/s | 1196.0 MB/s | **3.4x** | 576.8 MB/s | 2132.0 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 331.5 MB/s | 895.4 MB/s | **2.7x** | 294.5 MB/s | 1972.4 MB/s | **6.7x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 271.0 MB/s | 1040.6 MB/s | **3.8x** | 286.8 MB/s | 1068.1 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 213.5 MB/s | 1062.6 MB/s | **5.0x** | 277.4 MB/s | 1079.1 MB/s | **3.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 1033.7 MB/s | 3168.5 MB/s | **3.1x** | 1338.7 MB/s | 5349.3 MB/s | **4.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 901.7 MB/s | 3088.2 MB/s | **3.4x** | 780.9 MB/s | 5456.9 MB/s | **7.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 285.4 MB/s | 527.7 MB/s | **1.8x** | 718.8 MB/s | 3660.4 MB/s | **5.1x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 264.3 MB/s | 534.3 MB/s | **2.0x** | 603.2 MB/s | 3524.9 MB/s | **5.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 650.9 MB/s | 1702.5 MB/s | **2.6x** | 930.3 MB/s | 5446.7 MB/s | **5.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 641.0 MB/s | 1598.5 MB/s | **2.5x** | 1012.4 MB/s | 4532.5 MB/s | **4.5x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 77.8 MB/s | 1229.7 MB/s | **15.8x** | 938.2 MB/s | 5825.7 MB/s | **6.2x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 76.4 MB/s | 1163.9 MB/s | **15.2x** | 1017.3 MB/s | 4837.7 MB/s | **4.8x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1603.2 MB/s | 8361.2 MB/s | **5.2x** | 1590.4 MB/s | 4978.7 MB/s | **3.1x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1246.5 MB/s | 6004.6 MB/s | **4.8x** | 1558.7 MB/s | 4823.3 MB/s | **3.1x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 789.1 MB/s | 4921.0 MB/s | **6.2x** | 911.6 MB/s | 5426.4 MB/s | **6.0x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 753.2 MB/s | 4666.9 MB/s | **6.2x** | 894.3 MB/s | 5256.2 MB/s | **5.9x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 201.3 MB/s | 5386.3 MB/s | **26.8x** | 4078.3 MB/s | 6625.4 MB/s | **1.6x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 188.8 MB/s | 1338.5 MB/s | **7.1x** | 3078.6 MB/s | 8451.0 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 137.3 MB/s | 5700.5 MB/s | **41.5x** | 1648.9 MB/s | 7178.7 MB/s | **4.4x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 137.9 MB/s | 1339.2 MB/s | **9.7x** | 1432.8 MB/s | 8399.8 MB/s | **5.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 89.5 MB/s | 184.5 MB/s | **2.1x** | 3582.9 MB/s | 10800.1 MB/s | **3.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 81.4 MB/s | 175.0 MB/s | **2.2x** | 1853.9 MB/s | 2358.3 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 73.8 MB/s | 147.7 MB/s | **2.0x** | 3980.8 MB/s | 10163.6 MB/s | **2.6x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.8 MB/s | 140.8 MB/s | **2.0x** | 1838.0 MB/s | 2363.2 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5561.7 MB/s | 5018.7 MB/s | **0.9x** | 5880.8 MB/s | 3743.0 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 5677.9 MB/s | 5160.2 MB/s | **0.9x** | 7081.2 MB/s | 4434.1 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 978.6 MB/s | 1734.2 MB/s | **1.8x** | 1616.4 MB/s | 5600.2 MB/s | **3.5x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 958.5 MB/s | 1789.3 MB/s | **1.9x** | 1558.7 MB/s | 5736.6 MB/s | **3.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 4994.3 MB/s | 5287.6 MB/s | **1.1x** | 5100.3 MB/s | 8611.5 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 4837.7 MB/s | 4538.3 MB/s | **0.9x** | 4914.3 MB/s | 8304.0 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 655.1 MB/s | 4789.7 MB/s | **7.3x** | 3500.8 MB/s | 8765.8 MB/s | **2.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 662.6 MB/s | 4911.8 MB/s | **7.4x** | 3334.4 MB/s | 8842.4 MB/s | **2.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 990.2 MB/s | 1830.8 MB/s | **1.8x** | 1738.2 MB/s | 9745.4 MB/s | **5.6x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1014.5 MB/s | 1833.9 MB/s | **1.8x** | 1899.9 MB/s | 10093.6 MB/s | **5.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.3 MB/s | 1240.8 MB/s | **13.2x** | 1697.8 MB/s | 11724.2 MB/s | **6.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.4 MB/s | 1242.5 MB/s | **13.2x** | 1982.7 MB/s | 11620.4 MB/s | **5.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 14023.4 MB/s | 17380.8 MB/s | **1.2x** | 5489.7 MB/s | 4500.3 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 9041.2 MB/s | 20308.5 MB/s | **2.2x** | 5925.2 MB/s | 4958.3 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2049.6 MB/s | 10251.0 MB/s | **5.0x** | 1817.6 MB/s | 3065.1 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2043.7 MB/s | 10583.4 MB/s | **5.2x** | 1918.5 MB/s | 3198.1 MB/s | **1.7x** | - |
