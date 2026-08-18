# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 20:25:43 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 868.8 MB/s | 938.8 MB/s | **1.1x** | 717.5 MB/s | 1402.9 MB/s | **2.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 841.3 MB/s | 896.4 MB/s | **1.1x** | 547.8 MB/s | 1427.4 MB/s | **2.6x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 274.8 MB/s | 387.6 MB/s | **1.4x** | 567.7 MB/s | 1221.4 MB/s | **2.2x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 284.8 MB/s | 409.0 MB/s | **1.4x** | 465.4 MB/s | 1272.0 MB/s | **2.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 373.8 MB/s | 1127.6 MB/s | **3.0x** | 494.0 MB/s | 1905.2 MB/s | **3.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 394.8 MB/s | 751.5 MB/s | **1.9x** | 284.7 MB/s | 1608.6 MB/s | **5.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 286.1 MB/s | 1078.6 MB/s | **3.8x** | 484.9 MB/s | 1822.7 MB/s | **3.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 326.6 MB/s | 727.6 MB/s | **2.2x** | 275.3 MB/s | 1662.9 MB/s | **6.0x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 284.8 MB/s | 921.1 MB/s | **3.2x** | 278.4 MB/s | 990.2 MB/s | **3.6x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 238.9 MB/s | 954.0 MB/s | **4.0x** | 184.1 MB/s | 1000.7 MB/s | **5.4x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 924.8 MB/s | 2533.7 MB/s | **2.7x** | 1244.7 MB/s | 4123.6 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 845.1 MB/s | 2836.0 MB/s | **3.4x** | 775.1 MB/s | 3680.5 MB/s | **4.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 291.7 MB/s | 551.1 MB/s | **1.9x** | 944.7 MB/s | 3161.7 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 295.2 MB/s | 555.4 MB/s | **1.9x** | 640.7 MB/s | 3258.1 MB/s | **5.1x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 653.1 MB/s | 1728.0 MB/s | **2.6x** | 951.7 MB/s | 6457.5 MB/s | **6.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 596.9 MB/s | 1625.9 MB/s | **2.7x** | 981.3 MB/s | 4850.8 MB/s | **4.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 76.0 MB/s | 1230.9 MB/s | **16.2x** | 881.5 MB/s | 6526.7 MB/s | **7.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 75.5 MB/s | 1155.3 MB/s | **15.3x** | 913.0 MB/s | 4735.8 MB/s | **5.2x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1625.0 MB/s | 8619.8 MB/s | **5.3x** | 1560.8 MB/s | 4522.7 MB/s | **2.9x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1169.1 MB/s | 5578.8 MB/s | **4.8x** | 1359.9 MB/s | 4750.2 MB/s | **3.5x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 621.3 MB/s | 5012.0 MB/s | **8.1x** | 691.5 MB/s | 4898.0 MB/s | **7.1x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 738.1 MB/s | 5166.5 MB/s | **7.0x** | 908.4 MB/s | 4911.9 MB/s | **5.4x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 213.1 MB/s | 5642.4 MB/s | **26.5x** | 3955.2 MB/s | 4566.7 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 203.9 MB/s | 1248.9 MB/s | **6.1x** | 3275.3 MB/s | 4579.9 MB/s | **1.4x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 125.8 MB/s | 5420.0 MB/s | **43.1x** | 1520.8 MB/s | 4255.7 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 131.4 MB/s | 1308.4 MB/s | **10.0x** | 1388.9 MB/s | 4818.3 MB/s | **3.5x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 87.2 MB/s | 173.4 MB/s | **2.0x** | 3738.0 MB/s | 10287.3 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 81.7 MB/s | 167.4 MB/s | **2.0x** | 1783.1 MB/s | 2178.4 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.2 MB/s | 144.7 MB/s | **2.1x** | 3472.5 MB/s | 9915.1 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 69.2 MB/s | 123.4 MB/s | **1.8x** | 1798.4 MB/s | 2262.1 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5787.3 MB/s | 5387.1 MB/s | **0.9x** | 6802.9 MB/s | 3505.9 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 5509.2 MB/s | 4693.2 MB/s | **0.9x** | 6088.0 MB/s | 4051.6 MB/s | **0.7x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 948.7 MB/s | 1638.7 MB/s | **1.7x** | 1578.1 MB/s | 4999.6 MB/s | **3.2x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 909.6 MB/s | 1619.0 MB/s | **1.8x** | 1426.1 MB/s | 5371.5 MB/s | **3.8x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.11 MB (0.0%) | 5255.9 MB/s | 4770.5 MB/s | **0.9x** | 5070.4 MB/s | 5146.3 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.11 MB (0.0%) | 5138.7 MB/s | 4776.2 MB/s | **0.9x** | 4851.0 MB/s | 5025.1 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 604.4 MB/s | 3213.2 MB/s | **5.3x** | 3057.3 MB/s | 3955.4 MB/s | **1.3x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 660.4 MB/s | 4202.1 MB/s | **6.4x** | 3369.2 MB/s | 4383.8 MB/s | **1.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 989.2 MB/s | 1835.8 MB/s | **1.9x** | 1426.0 MB/s | 10153.6 MB/s | **7.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1029.0 MB/s | 1822.0 MB/s | **1.8x** | 1953.3 MB/s | 9475.0 MB/s | **4.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 89.4 MB/s | 1173.6 MB/s | **13.1x** | 1452.3 MB/s | 11478.5 MB/s | **7.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 92.6 MB/s | 1215.3 MB/s | **13.1x** | 1989.7 MB/s | 10739.1 MB/s | **5.4x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 12580.2 MB/s | 18305.3 MB/s | **1.5x** | 5680.0 MB/s | 4789.0 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 9644.1 MB/s | 20780.7 MB/s | **2.2x** | 5839.4 MB/s | 5033.6 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2145.2 MB/s | 9230.1 MB/s | **4.3x** | 1716.9 MB/s | 3108.7 MB/s | **1.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2002.2 MB/s | 10272.9 MB/s | **5.1x** | 1858.1 MB/s | 3111.8 MB/s | **1.7x** | - |
