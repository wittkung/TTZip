# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 15:50:45 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 747.4 MB/s | 516.7 MB/s | **0.7x** | 628.8 MB/s | 1087.4 MB/s | **1.7x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 711.6 MB/s | 404.0 MB/s | **0.6x** | 495.9 MB/s | 668.6 MB/s | **1.3x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 263.4 MB/s | 338.1 MB/s | **1.3x** | 462.5 MB/s | 1151.9 MB/s | **2.5x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 266.3 MB/s | 278.2 MB/s | **1.0x** | 426.6 MB/s | 645.8 MB/s | **1.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 425.2 MB/s | 1091.9 MB/s | **2.6x** | 517.2 MB/s | 1858.6 MB/s | **3.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 407.3 MB/s | 830.2 MB/s | **2.0x** | 275.7 MB/s | 1548.1 MB/s | **5.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 348.6 MB/s | 1102.1 MB/s | **3.2x** | 516.1 MB/s | 1948.2 MB/s | **3.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 328.6 MB/s | 792.9 MB/s | **2.4x** | 272.2 MB/s | 1699.3 MB/s | **6.2x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 243.5 MB/s | 939.7 MB/s | **3.9x** | 246.4 MB/s | 961.6 MB/s | **3.9x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 237.5 MB/s | 901.2 MB/s | **3.8x** | 193.6 MB/s | 979.9 MB/s | **5.1x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 963.3 MB/s | 813.4 MB/s | **0.8x** | 1230.2 MB/s | 3254.8 MB/s | **2.6x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 844.2 MB/s | 554.7 MB/s | **0.7x** | 732.5 MB/s | 1073.9 MB/s | **1.5x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 268.0 MB/s | 458.5 MB/s | **1.7x** | 836.8 MB/s | 3452.6 MB/s | **4.1x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 268.2 MB/s | 373.9 MB/s | **1.4x** | 581.2 MB/s | 1062.8 MB/s | **1.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 605.3 MB/s | 1562.0 MB/s | **2.6x** | 836.0 MB/s | 4938.4 MB/s | **5.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 591.0 MB/s | 1477.6 MB/s | **2.5x** | 904.1 MB/s | 4104.4 MB/s | **4.5x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 73.3 MB/s | 1124.9 MB/s | **15.3x** | 827.7 MB/s | 6281.2 MB/s | **7.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 72.8 MB/s | 1047.6 MB/s | **14.4x** | 867.2 MB/s | 4718.1 MB/s | **5.4x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1499.5 MB/s | 3681.8 MB/s | **2.5x** | 1382.1 MB/s | 4240.4 MB/s | **3.1x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1148.3 MB/s | 3792.0 MB/s | **3.3x** | 1296.5 MB/s | 4131.0 MB/s | **3.2x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 660.3 MB/s | 4001.7 MB/s | **6.1x** | 733.1 MB/s | 4599.3 MB/s | **6.3x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 642.9 MB/s | 3820.7 MB/s | **5.9x** | 749.8 MB/s | 3942.5 MB/s | **5.3x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 147.3 MB/s | 3788.5 MB/s | **25.7x** | 3764.8 MB/s | 4897.3 MB/s | **1.3x** | 2_SolidBuf_IO_and_CRC32 (88.6%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 147.7 MB/s | 3733.0 MB/s | **25.3x** | 2862.2 MB/s | 6178.2 MB/s | **2.2x** | 2_SolidBuf_IO_and_CRC32 (90.8%) |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 121.2 MB/s | 3664.4 MB/s | **30.2x** | 1461.2 MB/s | 6412.2 MB/s | **4.4x** | 2_SolidBuf_IO_and_CRC32 (90.4%) |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 120.0 MB/s | 3701.8 MB/s | **30.9x** | 1391.9 MB/s | 6495.0 MB/s | **4.7x** | 2_SolidBuf_IO_and_CRC32 (89.2%) |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 82.1 MB/s | 172.1 MB/s | **2.1x** | 3501.1 MB/s | 10176.3 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 77.4 MB/s | 162.3 MB/s | **2.1x** | 1163.8 MB/s | 2044.9 MB/s | **1.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.7 MB/s | 134.6 MB/s | **1.9x** | 3591.9 MB/s | 9817.2 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 64.1 MB/s | 135.8 MB/s | **2.1x** | 1598.6 MB/s | 2199.3 MB/s | **1.4x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 10.09 MB (10.1%) | 4983.9 MB/s | 5709.4 MB/s | **1.1x** | 4847.9 MB/s | 4856.2 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 10.09 MB (10.1%) | 4911.6 MB/s | 6668.0 MB/s | **1.4x** | 5217.0 MB/s | 5335.1 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 670.1 MB/s | 1273.4 MB/s | **1.9x** | 1125.4 MB/s | 4189.3 MB/s | **3.7x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 702.0 MB/s | 1315.8 MB/s | **1.9x** | 1192.2 MB/s | 4423.9 MB/s | **3.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5303.2 MB/s | 4033.2 MB/s | **0.8x** | 5251.6 MB/s | 5362.3 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 4888.5 MB/s | 3943.6 MB/s | **0.8x** | 4816.4 MB/s | 7690.3 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 615.4 MB/s | 3941.7 MB/s | **6.4x** | 3252.0 MB/s | 8263.8 MB/s | **2.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 619.7 MB/s | 3680.8 MB/s | **5.9x** | 3201.5 MB/s | 4766.2 MB/s | **1.5x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 993.2 MB/s | 1752.9 MB/s | **1.8x** | 1673.1 MB/s | 10113.9 MB/s | **6.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 965.6 MB/s | 1779.7 MB/s | **1.8x** | 1880.9 MB/s | 9951.2 MB/s | **5.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 90.3 MB/s | 1179.3 MB/s | **13.1x** | 1627.4 MB/s | 11319.7 MB/s | **7.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.7 MB/s | 1242.4 MB/s | **13.1x** | 2079.2 MB/s | 11990.6 MB/s | **5.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 15231.4 MB/s | 12508.5 MB/s | **0.8x** | 5772.6 MB/s | 7008.6 MB/s | **1.2x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10276.1 MB/s | 13311.3 MB/s | **1.3x** | 5645.5 MB/s | 6441.8 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 1868.2 MB/s | 9847.5 MB/s | **5.3x** | 1843.1 MB/s | 2833.4 MB/s | **1.5x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 1940.8 MB/s | 10613.5 MB/s | **5.5x** | 1948.5 MB/s | 3152.8 MB/s | **1.6x** | - |
