# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 20:05:59 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 891.1 MB/s | 918.1 MB/s | **1.0x** | 686.4 MB/s | 1340.6 MB/s | **2.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 752.5 MB/s | 819.3 MB/s | **1.1x** | 526.5 MB/s | 1341.7 MB/s | **2.5x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 288.4 MB/s | 416.4 MB/s | **1.4x** | 597.8 MB/s | 1179.7 MB/s | **2.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 286.3 MB/s | 407.2 MB/s | **1.4x** | 476.8 MB/s | 1259.2 MB/s | **2.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 440.2 MB/s | 1219.2 MB/s | **2.8x** | 601.3 MB/s | 1917.3 MB/s | **3.2x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 413.1 MB/s | 913.4 MB/s | **2.2x** | 280.3 MB/s | 1719.2 MB/s | **6.1x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 350.4 MB/s | 1006.8 MB/s | **2.9x** | 563.7 MB/s | 1564.2 MB/s | **2.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 342.3 MB/s | 921.1 MB/s | **2.7x** | 298.9 MB/s | 1859.8 MB/s | **6.2x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 266.7 MB/s | 1031.8 MB/s | **3.9x** | 280.9 MB/s | 590.4 MB/s | **2.1x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 270.3 MB/s | 1069.5 MB/s | **4.0x** | 283.5 MB/s | 854.6 MB/s | **3.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1069.5 MB/s | 1573.9 MB/s | **1.5x** | 693.6 MB/s | 3972.9 MB/s | **5.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 948.8 MB/s | 671.6 MB/s | **0.7x** | 823.0 MB/s | 3995.0 MB/s | **4.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 289.2 MB/s | 530.4 MB/s | **1.8x** | 919.1 MB/s | 3282.5 MB/s | **3.6x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 275.1 MB/s | 542.2 MB/s | **2.0x** | 642.8 MB/s | 2936.4 MB/s | **4.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 653.7 MB/s | 1725.2 MB/s | **2.6x** | 936.1 MB/s | 5613.0 MB/s | **6.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 640.7 MB/s | 1572.4 MB/s | **2.5x** | 997.9 MB/s | 4742.3 MB/s | **4.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 77.1 MB/s | 1216.3 MB/s | **15.8x** | 928.0 MB/s | 5163.5 MB/s | **5.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 76.1 MB/s | 1140.1 MB/s | **15.0x** | 1006.0 MB/s | 4836.8 MB/s | **4.8x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1690.7 MB/s | 6818.4 MB/s | **4.0x** | 1579.3 MB/s | 4714.1 MB/s | **3.0x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1265.3 MB/s | 1825.8 MB/s | **1.4x** | 1558.8 MB/s | 4696.0 MB/s | **3.0x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 771.1 MB/s | 5125.6 MB/s | **6.6x** | 903.2 MB/s | 5167.1 MB/s | **5.7x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 773.1 MB/s | 4571.5 MB/s | **5.9x** | 917.0 MB/s | 5523.4 MB/s | **6.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 214.7 MB/s | 4327.6 MB/s | **20.2x** | 4016.7 MB/s | 3765.8 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 169.0 MB/s | 1256.2 MB/s | **7.4x** | 3021.9 MB/s | 4796.9 MB/s | **1.6x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 133.2 MB/s | 2462.4 MB/s | **18.5x** | 1585.9 MB/s | 1838.1 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 142.8 MB/s | 1270.5 MB/s | **8.9x** | 1378.1 MB/s | 4118.8 MB/s | **3.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 89.1 MB/s | 183.4 MB/s | **2.1x** | 3731.6 MB/s | 8834.5 MB/s | **2.4x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 82.2 MB/s | 171.5 MB/s | **2.1x** | 1599.4 MB/s | 2150.1 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.8 MB/s | 138.0 MB/s | **1.9x** | 3603.3 MB/s | 9036.2 MB/s | **2.5x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 64.1 MB/s | 137.6 MB/s | **2.1x** | 1642.5 MB/s | 2204.3 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4448.2 MB/s | 3229.6 MB/s | **0.7x** | 5241.7 MB/s | 3734.9 MB/s | **0.7x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 10.01 MB (10.0%) | 4861.2 MB/s | 11649.5 MB/s | **2.4x** | 4655.2 MB/s | 4115.9 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 793.2 MB/s | 1532.1 MB/s | **1.9x** | 746.1 MB/s | 5649.3 MB/s | **7.6x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 849.3 MB/s | 827.7 MB/s | **1.0x** | 1555.9 MB/s | 2423.2 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5621.1 MB/s | 21227.1 MB/s | **3.8x** | 5371.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5428.9 MB/s | 21003.8 MB/s | **3.9x** | 4822.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 670.5 MB/s | 20574.4 MB/s | **30.7x** | 3628.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 674.5 MB/s | 20595.1 MB/s | **30.5x** | 3553.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1021.7 MB/s | 1850.2 MB/s | **1.8x** | 1600.1 MB/s | 6885.6 MB/s | **4.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 979.4 MB/s | 1844.4 MB/s | **1.9x** | 1717.3 MB/s | 7318.0 MB/s | **4.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.9 MB/s | 1246.3 MB/s | **13.3x** | 1723.0 MB/s | 11514.5 MB/s | **6.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.2 MB/s | 1250.8 MB/s | **13.3x** | 2041.5 MB/s | 11989.8 MB/s | **5.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 14052.9 MB/s | 18809.2 MB/s | **1.3x** | 5811.4 MB/s | 4728.7 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10945.7 MB/s | 19732.8 MB/s | **1.8x** | 5928.1 MB/s | 5012.4 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2147.1 MB/s | 10573.8 MB/s | **4.9x** | 1961.0 MB/s | 3181.0 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2076.2 MB/s | 10659.6 MB/s | **5.1x** | 1986.2 MB/s | 3131.4 MB/s | **1.6x** | - |
