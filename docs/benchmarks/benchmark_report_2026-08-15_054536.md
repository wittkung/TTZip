# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 21:45:36 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 801.3 MB/s | 1997.5 MB/s | **2.5x** | 660.7 MB/s | 1370.0 MB/s | **2.1x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 764.5 MB/s | 2080.4 MB/s | **2.7x** | 501.4 MB/s | 1461.6 MB/s | **2.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 287.8 MB/s | 528.2 MB/s | **1.8x** | 535.4 MB/s | 1238.3 MB/s | **2.3x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 285.5 MB/s | 616.5 MB/s | **2.2x** | 475.7 MB/s | 1289.0 MB/s | **2.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 435.2 MB/s | 1219.1 MB/s | **2.8x** | 550.6 MB/s | 2372.6 MB/s | **4.3x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 425.2 MB/s | 928.5 MB/s | **2.2x** | 294.1 MB/s | 1811.5 MB/s | **6.2x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 366.3 MB/s | 1217.6 MB/s | **3.3x** | 261.0 MB/s | 2133.7 MB/s | **8.2x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 310.0 MB/s | 885.7 MB/s | **2.9x** | 291.8 MB/s | 1864.9 MB/s | **6.4x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 264.7 MB/s | 1027.5 MB/s | **3.9x** | 264.0 MB/s | 1038.6 MB/s | **3.9x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 242.1 MB/s | 945.8 MB/s | **3.9x** | 271.8 MB/s | 1052.0 MB/s | **3.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 910.2 MB/s | 2429.5 MB/s | **2.7x** | 1094.3 MB/s | 3990.8 MB/s | **3.6x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 822.7 MB/s | 2328.8 MB/s | **2.8x** | 723.4 MB/s | 4170.0 MB/s | **5.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 281.2 MB/s | 515.0 MB/s | **1.8x** | 805.1 MB/s | 3252.4 MB/s | **4.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 274.3 MB/s | 547.0 MB/s | **2.0x** | 558.3 MB/s | 2622.4 MB/s | **4.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 618.9 MB/s | 1595.3 MB/s | **2.6x** | 808.5 MB/s | 5054.4 MB/s | **6.3x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 595.9 MB/s | 1396.8 MB/s | **2.3x** | 855.5 MB/s | 3456.8 MB/s | **4.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 74.7 MB/s | 1164.4 MB/s | **15.6x** | 596.8 MB/s | 4001.5 MB/s | **6.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 74.1 MB/s | 1081.6 MB/s | **14.6x** | 898.9 MB/s | 3939.9 MB/s | **4.4x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1521.5 MB/s | 8077.9 MB/s | **5.3x** | 1393.5 MB/s | 4924.0 MB/s | **3.5x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1188.4 MB/s | 5359.4 MB/s | **4.5x** | 1404.3 MB/s | 4815.8 MB/s | **3.4x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 702.5 MB/s | 4042.0 MB/s | **5.8x** | 835.9 MB/s | 4864.3 MB/s | **5.8x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 712.0 MB/s | 4462.5 MB/s | **6.3x** | 884.0 MB/s | 4557.1 MB/s | **5.2x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 126.7 MB/s | 4731.2 MB/s | **37.3x** | 3800.0 MB/s | 5464.1 MB/s | **1.4x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 128.6 MB/s | 1313.0 MB/s | **10.2x** | 2795.4 MB/s | 6477.6 MB/s | **2.3x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 110.7 MB/s | 4743.5 MB/s | **42.8x** | 1530.1 MB/s | 5507.1 MB/s | **3.6x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 78.0 MB/s | 1175.5 MB/s | **15.1x** | 1383.1 MB/s | 5061.3 MB/s | **3.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 36.4 MB/s | 180.1 MB/s | **5.0x** | 2596.0 MB/s | 7822.8 MB/s | **3.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 43.0 MB/s | 117.7 MB/s | **2.7x** | 326.0 MB/s | 1033.6 MB/s | **3.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 46.1 MB/s | 72.2 MB/s | **1.6x** | 951.9 MB/s | 7828.6 MB/s | **8.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 41.3 MB/s | 87.3 MB/s | **2.1x** | 683.2 MB/s | 1327.4 MB/s | **1.9x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 1644.5 MB/s | 2009.7 MB/s | **1.2x** | 2302.2 MB/s | 1245.8 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 3415.4 MB/s | 2459.9 MB/s | **0.7x** | 4533.2 MB/s | 1677.0 MB/s | **0.4x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 261.8 MB/s | 1051.6 MB/s | **4.0x** | 1182.3 MB/s | 2481.1 MB/s | **2.1x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 452.3 MB/s | 812.7 MB/s | **1.8x** | 866.2 MB/s | 1386.5 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 3343.8 MB/s | 3478.7 MB/s | **1.0x** | 4414.1 MB/s | 4400.8 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 4105.9 MB/s | 3717.1 MB/s | **0.9x** | 4033.8 MB/s | 4117.8 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 484.9 MB/s | 3746.7 MB/s | **7.7x** | 2620.4 MB/s | 4200.6 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 500.8 MB/s | 3768.3 MB/s | **7.5x** | 2958.3 MB/s | 4075.1 MB/s | **1.4x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 915.0 MB/s | 1650.5 MB/s | **1.8x** | 1448.9 MB/s | 4826.5 MB/s | **3.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 910.0 MB/s | 1548.5 MB/s | **1.7x** | 1289.0 MB/s | 7044.0 MB/s | **5.5x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.7 MB/s | 1191.9 MB/s | **12.7x** | 1688.2 MB/s | 7294.2 MB/s | **4.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.1 MB/s | 1223.1 MB/s | **13.1x** | 2022.1 MB/s | 6648.6 MB/s | **3.3x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 13166.5 MB/s | 21618.3 MB/s | **1.6x** | 5589.9 MB/s | 5049.2 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 1968.2 MB/s | 20658.0 MB/s | **10.5x** | 2808.1 MB/s | 4910.7 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2380.0 MB/s | 9730.3 MB/s | **4.1x** | 1886.6 MB/s | 2939.9 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2081.9 MB/s | 9929.9 MB/s | **4.8x** | 1948.2 MB/s | 3114.9 MB/s | **1.6x** | - |
