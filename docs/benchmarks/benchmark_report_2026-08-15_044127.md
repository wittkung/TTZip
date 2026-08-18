# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 20:41:27 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 833.3 MB/s | 892.8 MB/s | **1.1x** | 658.0 MB/s | 1521.9 MB/s | **2.3x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 842.7 MB/s | 898.3 MB/s | **1.1x** | 565.6 MB/s | 1626.9 MB/s | **2.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 297.2 MB/s | 406.6 MB/s | **1.4x** | 605.9 MB/s | 1478.8 MB/s | **2.4x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 268.4 MB/s | 415.8 MB/s | **1.5x** | 463.6 MB/s | 1138.2 MB/s | **2.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 464.6 MB/s | 1107.2 MB/s | **2.4x** | 594.4 MB/s | 2241.0 MB/s | **3.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 435.3 MB/s | 810.1 MB/s | **1.9x** | 285.8 MB/s | 1963.8 MB/s | **6.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 361.4 MB/s | 1166.2 MB/s | **3.2x** | 564.4 MB/s | 1942.1 MB/s | **3.4x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 337.3 MB/s | 858.7 MB/s | **2.5x** | 287.2 MB/s | 2001.2 MB/s | **7.0x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 240.4 MB/s | 950.2 MB/s | **4.0x** | 280.0 MB/s | 1089.1 MB/s | **3.9x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 238.0 MB/s | 1006.4 MB/s | **4.2x** | 285.5 MB/s | 1020.8 MB/s | **3.6x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 885.9 MB/s | 2052.1 MB/s | **2.3x** | 1153.8 MB/s | 4768.8 MB/s | **4.1x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 747.7 MB/s | 2995.2 MB/s | **4.0x** | 686.2 MB/s | 4919.3 MB/s | **7.2x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 289.5 MB/s | 489.8 MB/s | **1.7x** | 878.8 MB/s | 3297.3 MB/s | **3.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 279.2 MB/s | 480.8 MB/s | **1.7x** | 544.7 MB/s | 3067.9 MB/s | **5.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 604.6 MB/s | 1727.2 MB/s | **2.9x** | 884.6 MB/s | 5076.2 MB/s | **5.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 595.0 MB/s | 1543.3 MB/s | **2.6x** | 968.3 MB/s | 4279.0 MB/s | **4.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 79.8 MB/s | 1176.1 MB/s | **14.7x** | 845.9 MB/s | 6053.1 MB/s | **7.2x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 79.5 MB/s | 1148.5 MB/s | **14.4x** | 887.0 MB/s | 4412.7 MB/s | **5.0x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1384.7 MB/s | 7538.6 MB/s | **5.4x** | 1431.7 MB/s | 5214.1 MB/s | **3.6x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1080.9 MB/s | 5199.0 MB/s | **4.8x** | 1379.0 MB/s | 4378.0 MB/s | **3.2x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.7%) | 0.03 MB (0.4%) | 716.2 MB/s | 4233.3 MB/s | **5.9x** | 858.0 MB/s | 4931.0 MB/s | **5.7x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 668.0 MB/s | 4784.8 MB/s | **7.2x** | 848.5 MB/s | 5213.6 MB/s | **6.1x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 205.3 MB/s | 5054.4 MB/s | **24.6x** | 3851.7 MB/s | 5837.4 MB/s | **1.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 200.5 MB/s | 1337.1 MB/s | **6.7x** | 3135.8 MB/s | 7778.5 MB/s | **2.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 142.6 MB/s | 5226.4 MB/s | **36.7x** | 1624.3 MB/s | 6336.5 MB/s | **3.9x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 141.5 MB/s | 1354.4 MB/s | **9.6x** | 1497.2 MB/s | 7498.5 MB/s | **5.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 87.0 MB/s | 182.3 MB/s | **2.1x** | 3698.5 MB/s | 9895.4 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 82.4 MB/s | 174.2 MB/s | **2.1x** | 1803.8 MB/s | 2247.7 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 73.5 MB/s | 145.0 MB/s | **2.0x** | 3532.8 MB/s | 10303.6 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 67.2 MB/s | 140.2 MB/s | **2.1x** | 1732.5 MB/s | 2238.0 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5313.1 MB/s | 5207.1 MB/s | **1.0x** | 6757.2 MB/s | 4154.0 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 5576.7 MB/s | 5225.8 MB/s | **0.9x** | 6867.2 MB/s | 3934.5 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 885.2 MB/s | 1716.1 MB/s | **1.9x** | 1439.9 MB/s | 4977.7 MB/s | **3.5x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 817.7 MB/s | 1634.2 MB/s | **2.0x** | 1546.3 MB/s | 4693.6 MB/s | **3.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 4221.0 MB/s | 4009.3 MB/s | **0.9x** | 5283.9 MB/s | 8155.9 MB/s | **1.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5134.7 MB/s | 4069.1 MB/s | **0.8x** | 5180.4 MB/s | 9118.3 MB/s | **1.8x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 672.7 MB/s | 4441.1 MB/s | **6.6x** | 3698.7 MB/s | 9363.3 MB/s | **2.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 663.7 MB/s | 4300.0 MB/s | **6.5x** | 3659.7 MB/s | 9146.6 MB/s | **2.5x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1009.0 MB/s | 1824.7 MB/s | **1.8x** | 1644.6 MB/s | 10543.2 MB/s | **6.4x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 958.8 MB/s | 1795.2 MB/s | **1.9x** | 1880.2 MB/s | 9424.8 MB/s | **5.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 90.9 MB/s | 1222.9 MB/s | **13.5x** | 1579.1 MB/s | 11420.5 MB/s | **7.2x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 90.3 MB/s | 1229.9 MB/s | **13.6x** | 1817.5 MB/s | 10935.3 MB/s | **6.0x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 8282.9 MB/s | 20487.5 MB/s | **2.5x** | 5582.7 MB/s | 5069.9 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 9463.8 MB/s | 19004.4 MB/s | **2.0x** | 5951.0 MB/s | 5146.4 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 1975.6 MB/s | 9724.1 MB/s | **4.9x** | 1903.3 MB/s | 3080.6 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 1905.7 MB/s | 9712.0 MB/s | **5.1x** | 1917.2 MB/s | 3048.9 MB/s | **1.6x** | - |
