# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 21:56:00 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 807.1 MB/s | 1454.8 MB/s | **1.8x** | 689.7 MB/s | 1255.1 MB/s | **1.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 780.3 MB/s | 1588.6 MB/s | **2.0x** | 499.3 MB/s | 1405.5 MB/s | **2.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 287.0 MB/s | 548.7 MB/s | **1.9x** | 563.7 MB/s | 1399.5 MB/s | **2.5x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 281.9 MB/s | 586.6 MB/s | **2.1x** | 477.4 MB/s | 1354.7 MB/s | **2.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 420.3 MB/s | 1200.2 MB/s | **2.9x** | 586.9 MB/s | 2029.5 MB/s | **3.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 441.1 MB/s | 889.8 MB/s | **2.0x** | 295.8 MB/s | 1864.4 MB/s | **6.3x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 381.4 MB/s | 1196.9 MB/s | **3.1x** | 551.0 MB/s | 2228.0 MB/s | **4.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 346.4 MB/s | 896.7 MB/s | **2.6x** | 297.8 MB/s | 1853.6 MB/s | **6.2x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 264.8 MB/s | 980.1 MB/s | **3.7x** | 273.0 MB/s | 1015.6 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 162.9 MB/s | 1047.3 MB/s | **6.4x** | 270.0 MB/s | 1085.5 MB/s | **4.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1002.7 MB/s | 1788.9 MB/s | **1.8x** | 1284.2 MB/s | 4709.9 MB/s | **3.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 918.9 MB/s | 1726.3 MB/s | **1.9x** | 806.9 MB/s | 4777.2 MB/s | **5.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 299.3 MB/s | 545.1 MB/s | **1.8x** | 941.6 MB/s | 3947.9 MB/s | **4.2x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 288.2 MB/s | 545.5 MB/s | **1.9x** | 630.5 MB/s | 3815.5 MB/s | **6.1x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 649.8 MB/s | 1709.1 MB/s | **2.6x** | 928.7 MB/s | 5831.6 MB/s | **6.3x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 631.9 MB/s | 1599.4 MB/s | **2.5x** | 1012.3 MB/s | 4667.7 MB/s | **4.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 74.1 MB/s | 1224.9 MB/s | **16.5x** | 859.3 MB/s | 6753.0 MB/s | **7.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 74.5 MB/s | 1125.5 MB/s | **15.1x** | 962.3 MB/s | 3795.2 MB/s | **3.9x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1360.8 MB/s | 8315.5 MB/s | **6.1x** | 1461.2 MB/s | 4463.4 MB/s | **3.1x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1079.4 MB/s | 5732.8 MB/s | **5.3x** | 1388.2 MB/s | 4083.4 MB/s | **2.9x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 744.3 MB/s | 4103.8 MB/s | **5.5x** | 793.8 MB/s | 4284.3 MB/s | **5.4x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 747.7 MB/s | 4745.4 MB/s | **6.3x** | 814.0 MB/s | 5187.6 MB/s | **6.4x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 164.4 MB/s | 4769.0 MB/s | **29.0x** | 3998.9 MB/s | 5941.5 MB/s | **1.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 155.3 MB/s | 1247.8 MB/s | **8.0x** | 2959.3 MB/s | 7294.1 MB/s | **2.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 137.7 MB/s | 5372.1 MB/s | **39.0x** | 1567.7 MB/s | 6095.3 MB/s | **3.9x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 133.2 MB/s | 1358.1 MB/s | **10.2x** | 1458.1 MB/s | 6659.3 MB/s | **4.6x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 86.0 MB/s | 182.8 MB/s | **2.1x** | 3752.6 MB/s | 9827.8 MB/s | **2.6x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 83.2 MB/s | 176.6 MB/s | **2.1x** | 1783.2 MB/s | 2311.8 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 75.1 MB/s | 147.5 MB/s | **2.0x** | 3678.3 MB/s | 9783.3 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 69.3 MB/s | 140.4 MB/s | **2.0x** | 1767.5 MB/s | 2298.2 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4101.3 MB/s | 4844.9 MB/s | **1.2x** | 6802.0 MB/s | 3452.2 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 5345.8 MB/s | 5005.9 MB/s | **0.9x** | 6937.9 MB/s | 4171.2 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 995.2 MB/s | 1755.4 MB/s | **1.8x** | 1628.0 MB/s | 5022.7 MB/s | **3.1x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 907.5 MB/s | 1776.6 MB/s | **2.0x** | 1564.7 MB/s | 4934.0 MB/s | **3.2x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5237.6 MB/s | 4778.6 MB/s | **0.9x** | 5359.5 MB/s | 8578.0 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5126.6 MB/s | 4841.5 MB/s | **0.9x** | 5162.0 MB/s | 8998.4 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 669.1 MB/s | 4858.1 MB/s | **7.3x** | 3439.9 MB/s | 8958.6 MB/s | **2.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 676.5 MB/s | 4885.8 MB/s | **7.2x** | 3538.7 MB/s | 9100.8 MB/s | **2.6x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1019.0 MB/s | 1844.0 MB/s | **1.8x** | 1728.1 MB/s | 9930.0 MB/s | **5.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1019.3 MB/s | 1840.7 MB/s | **1.8x** | 2050.3 MB/s | 10211.0 MB/s | **5.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.7 MB/s | 1252.9 MB/s | **13.2x** | 1728.1 MB/s | 12029.1 MB/s | **7.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 95.1 MB/s | 1251.1 MB/s | **13.2x** | 2086.8 MB/s | 11849.5 MB/s | **5.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 15003.0 MB/s | 18648.9 MB/s | **1.2x** | 5716.8 MB/s | 5110.8 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10147.5 MB/s | 19115.1 MB/s | **1.9x** | 5973.1 MB/s | 5308.5 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2238.1 MB/s | 10784.6 MB/s | **4.8x** | 1967.8 MB/s | 3244.1 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2065.8 MB/s | 10606.7 MB/s | **5.1x** | 1890.3 MB/s | 3198.6 MB/s | **1.7x** | - |
