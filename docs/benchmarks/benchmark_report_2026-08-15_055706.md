# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 21:57:06 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 880.4 MB/s | 1509.2 MB/s | **1.7x** | 712.9 MB/s | 1445.4 MB/s | **2.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 840.4 MB/s | 1651.8 MB/s | **2.0x** | 540.2 MB/s | 1497.0 MB/s | **2.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 288.4 MB/s | 581.7 MB/s | **2.0x** | 609.3 MB/s | 1372.5 MB/s | **2.3x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 287.8 MB/s | 626.6 MB/s | **2.2x** | 478.6 MB/s | 1276.3 MB/s | **2.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 436.1 MB/s | 1201.5 MB/s | **2.8x** | 587.4 MB/s | 2223.4 MB/s | **3.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 416.3 MB/s | 915.6 MB/s | **2.2x** | 299.6 MB/s | 1936.9 MB/s | **6.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 345.1 MB/s | 1289.9 MB/s | **3.7x** | 582.6 MB/s | 2191.9 MB/s | **3.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 338.7 MB/s | 942.3 MB/s | **2.8x** | 296.8 MB/s | 1957.1 MB/s | **6.6x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 272.6 MB/s | 1069.3 MB/s | **3.9x** | 286.0 MB/s | 1064.5 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 277.4 MB/s | 1072.8 MB/s | **3.9x** | 279.0 MB/s | 1053.0 MB/s | **3.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1051.1 MB/s | 1857.7 MB/s | **1.8x** | 1389.2 MB/s | 4622.2 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 863.5 MB/s | 1700.0 MB/s | **2.0x** | 758.7 MB/s | 3136.2 MB/s | **4.1x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 284.7 MB/s | 563.9 MB/s | **2.0x** | 965.0 MB/s | 3577.8 MB/s | **3.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 285.3 MB/s | 568.1 MB/s | **2.0x** | 666.8 MB/s | 3711.9 MB/s | **5.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 648.4 MB/s | 1768.4 MB/s | **2.7x** | 970.5 MB/s | 5955.0 MB/s | **6.1x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 651.5 MB/s | 1636.1 MB/s | **2.5x** | 1045.2 MB/s | 4802.8 MB/s | **4.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 78.7 MB/s | 1242.6 MB/s | **15.8x** | 958.6 MB/s | 6523.7 MB/s | **6.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 77.5 MB/s | 1175.2 MB/s | **15.2x** | 1014.9 MB/s | 4939.3 MB/s | **4.9x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1653.5 MB/s | 9198.4 MB/s | **5.6x** | 1564.5 MB/s | 5195.9 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1239.4 MB/s | 5492.7 MB/s | **4.4x** | 1545.3 MB/s | 5185.4 MB/s | **3.4x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 738.9 MB/s | 4964.5 MB/s | **6.7x** | 912.6 MB/s | 5451.5 MB/s | **6.0x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 780.3 MB/s | 5284.8 MB/s | **6.8x** | 925.0 MB/s | 5377.9 MB/s | **5.8x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 213.1 MB/s | 5088.6 MB/s | **23.9x** | 4136.2 MB/s | 6213.3 MB/s | **1.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 212.7 MB/s | 1222.3 MB/s | **5.7x** | 3209.3 MB/s | 7252.0 MB/s | **2.3x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 134.6 MB/s | 5593.0 MB/s | **41.5x** | 1625.3 MB/s | 6420.8 MB/s | **4.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 141.4 MB/s | 1358.5 MB/s | **9.6x** | 1568.7 MB/s | 7530.3 MB/s | **4.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 87.3 MB/s | 181.5 MB/s | **2.1x** | 3947.2 MB/s | 10679.3 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 81.4 MB/s | 173.3 MB/s | **2.1x** | 1807.6 MB/s | 2389.4 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 73.2 MB/s | 146.5 MB/s | **2.0x** | 3904.5 MB/s | 10510.9 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 69.5 MB/s | 140.1 MB/s | **2.0x** | 1803.8 MB/s | 2375.1 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5538.1 MB/s | 5110.5 MB/s | **0.9x** | 6590.3 MB/s | 3761.4 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 5576.1 MB/s | 5247.3 MB/s | **0.9x** | 7101.8 MB/s | 4530.1 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 934.7 MB/s | 1732.4 MB/s | **1.9x** | 1556.9 MB/s | 5776.9 MB/s | **3.7x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 920.8 MB/s | 1730.4 MB/s | **1.9x** | 1606.6 MB/s | 5434.3 MB/s | **3.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 4960.8 MB/s | 4973.9 MB/s | **1.0x** | 5277.3 MB/s | 7813.7 MB/s | **1.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 4534.6 MB/s | 4823.5 MB/s | **1.1x** | 5248.5 MB/s | 9048.4 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 601.6 MB/s | 4707.7 MB/s | **7.8x** | 914.8 MB/s | 9438.2 MB/s | **10.3x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 651.9 MB/s | 4775.7 MB/s | **7.3x** | 3386.0 MB/s | 8982.1 MB/s | **2.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 938.2 MB/s | 1754.0 MB/s | **1.9x** | 1647.0 MB/s | 9887.7 MB/s | **6.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 995.9 MB/s | 1809.0 MB/s | **1.8x** | 1914.9 MB/s | 10214.1 MB/s | **5.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.8 MB/s | 1251.8 MB/s | **13.2x** | 1660.8 MB/s | 10883.5 MB/s | **6.6x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 95.2 MB/s | 1240.0 MB/s | **13.0x** | 2024.9 MB/s | 10760.4 MB/s | **5.3x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 14617.5 MB/s | 19318.1 MB/s | **1.3x** | 5592.4 MB/s | 4492.0 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 9890.2 MB/s | 22231.9 MB/s | **2.2x** | 5690.5 MB/s | 5049.9 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2215.0 MB/s | 10990.4 MB/s | **5.0x** | 1951.3 MB/s | 3068.2 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2088.5 MB/s | 10768.1 MB/s | **5.2x** | 2003.7 MB/s | 3121.9 MB/s | **1.6x** | - |
