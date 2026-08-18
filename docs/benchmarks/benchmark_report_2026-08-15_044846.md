# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 20:48:46 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 903.6 MB/s | 927.2 MB/s | **1.0x** | 741.5 MB/s | 1406.7 MB/s | **1.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 883.9 MB/s | 931.0 MB/s | **1.1x** | 565.9 MB/s | 1518.4 MB/s | **2.7x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 298.1 MB/s | 422.3 MB/s | **1.4x** | 594.7 MB/s | 1451.9 MB/s | **2.4x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 292.4 MB/s | 445.4 MB/s | **1.5x** | 508.2 MB/s | 1407.9 MB/s | **2.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 514.6 MB/s | 1259.2 MB/s | **2.4x** | 598.6 MB/s | 2242.6 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 471.3 MB/s | 918.2 MB/s | **1.9x** | 302.6 MB/s | 1924.3 MB/s | **6.4x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 407.7 MB/s | 1255.0 MB/s | **3.1x** | 595.1 MB/s | 2237.7 MB/s | **3.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 376.9 MB/s | 939.2 MB/s | **2.5x** | 297.9 MB/s | 1824.7 MB/s | **6.1x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 281.4 MB/s | 989.4 MB/s | **3.5x** | 280.4 MB/s | 1085.3 MB/s | **3.9x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 279.4 MB/s | 1034.0 MB/s | **3.7x** | 263.9 MB/s | 1079.0 MB/s | **4.1x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1076.7 MB/s | 374.8 MB/s | **0.3x** | 1389.0 MB/s | 2030.5 MB/s | **1.5x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 892.7 MB/s | 361.2 MB/s | **0.4x** | 812.5 MB/s | 2075.1 MB/s | **2.6x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 296.5 MB/s | 571.3 MB/s | **1.9x** | 978.5 MB/s | 3901.7 MB/s | **4.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 292.4 MB/s | 572.8 MB/s | **2.0x** | 675.9 MB/s | 3959.9 MB/s | **5.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 657.0 MB/s | 1732.9 MB/s | **2.6x** | 933.3 MB/s | 6534.4 MB/s | **7.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 641.8 MB/s | 1604.2 MB/s | **2.5x** | 1010.3 MB/s | 5030.6 MB/s | **5.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 75.8 MB/s | 1211.5 MB/s | **16.0x** | 949.8 MB/s | 6580.9 MB/s | **6.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 77.2 MB/s | 1156.8 MB/s | **15.0x** | 1022.1 MB/s | 5194.2 MB/s | **5.1x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1656.5 MB/s | 8761.4 MB/s | **5.3x** | 1748.7 MB/s | 5418.4 MB/s | **3.1x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1263.2 MB/s | 6224.8 MB/s | **4.9x** | 1595.3 MB/s | 5320.9 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 786.0 MB/s | 4901.3 MB/s | **6.2x** | 930.2 MB/s | 5821.6 MB/s | **6.3x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 770.0 MB/s | 4761.2 MB/s | **6.2x** | 941.9 MB/s | 6053.4 MB/s | **6.4x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 215.0 MB/s | 5092.9 MB/s | **23.7x** | 4158.4 MB/s | 6740.3 MB/s | **1.6x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 214.9 MB/s | 1321.4 MB/s | **6.1x** | 3274.7 MB/s | 7915.5 MB/s | **2.4x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 146.7 MB/s | 5448.0 MB/s | **37.1x** | 1705.9 MB/s | 6788.0 MB/s | **4.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 145.8 MB/s | 1388.9 MB/s | **9.5x** | 1550.2 MB/s | 7727.4 MB/s | **5.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 84.6 MB/s | 181.1 MB/s | **2.1x** | 3799.9 MB/s | 10930.0 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 79.8 MB/s | 170.4 MB/s | **2.1x** | 1827.1 MB/s | 2295.0 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 72.0 MB/s | 146.4 MB/s | **2.0x** | 3710.5 MB/s | 11006.8 MB/s | **3.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 66.8 MB/s | 140.5 MB/s | **2.1x** | 1808.1 MB/s | 2322.3 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4553.3 MB/s | 4646.2 MB/s | **1.0x** | 4984.9 MB/s | 3749.2 MB/s | **0.8x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 5950.4 MB/s | 4613.2 MB/s | **0.8x** | 6243.4 MB/s | 4178.8 MB/s | **0.7x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 960.6 MB/s | 1717.9 MB/s | **1.8x** | 1424.2 MB/s | 5776.1 MB/s | **4.1x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 883.9 MB/s | 1733.9 MB/s | **2.0x** | 1536.7 MB/s | 4914.8 MB/s | **3.2x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4704.0 MB/s | 4495.0 MB/s | **1.0x** | 4577.8 MB/s | 8788.0 MB/s | **1.9x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4070.4 MB/s | 4326.0 MB/s | **1.1x** | 2807.4 MB/s | 9148.0 MB/s | **3.3x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 635.0 MB/s | 4263.4 MB/s | **6.7x** | 3529.5 MB/s | 6791.8 MB/s | **1.9x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 665.2 MB/s | 4565.3 MB/s | **6.9x** | 3393.0 MB/s | 9422.8 MB/s | **2.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1018.7 MB/s | 1843.0 MB/s | **1.8x** | 1701.8 MB/s | 10621.3 MB/s | **6.2x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1017.2 MB/s | 1843.6 MB/s | **1.8x** | 2023.8 MB/s | 10486.6 MB/s | **5.2x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.9 MB/s | 1203.2 MB/s | **12.8x** | 1560.5 MB/s | 11932.6 MB/s | **7.6x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.5 MB/s | 1236.6 MB/s | **13.2x** | 2012.4 MB/s | 11534.9 MB/s | **5.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 15695.3 MB/s | 18883.0 MB/s | **1.2x** | 5407.0 MB/s | 5785.7 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10761.9 MB/s | 23081.0 MB/s | **2.1x** | 5491.3 MB/s | 5876.9 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2232.8 MB/s | 10664.4 MB/s | **4.8x** | 1748.8 MB/s | 3140.5 MB/s | **1.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 1997.9 MB/s | 10776.3 MB/s | **5.4x** | 1941.7 MB/s | 3192.3 MB/s | **1.6x** | - |
