# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 20:23:07 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 892.8 MB/s | 916.9 MB/s | **1.0x** | 752.5 MB/s | 1284.4 MB/s | **1.7x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 856.0 MB/s | 750.2 MB/s | **0.9x** | 547.8 MB/s | 1437.1 MB/s | **2.6x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 296.1 MB/s | 413.7 MB/s | **1.4x** | 635.6 MB/s | 1243.2 MB/s | **2.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 290.8 MB/s | 420.0 MB/s | **1.4x** | 497.9 MB/s | 1220.8 MB/s | **2.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 502.8 MB/s | 1222.9 MB/s | **2.4x** | 601.3 MB/s | 2060.4 MB/s | **3.4x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 434.5 MB/s | 742.6 MB/s | **1.7x** | 305.5 MB/s | 1143.8 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 347.8 MB/s | 979.7 MB/s | **2.8x** | 487.8 MB/s | 1993.4 MB/s | **4.1x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 318.3 MB/s | 687.8 MB/s | **2.2x** | 260.9 MB/s | 1562.8 MB/s | **6.0x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 246.5 MB/s | 780.3 MB/s | **3.2x** | 234.9 MB/s | 609.0 MB/s | **2.6x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 258.5 MB/s | 740.3 MB/s | **2.9x** | 260.1 MB/s | 629.9 MB/s | **2.4x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1027.1 MB/s | 2314.3 MB/s | **2.3x** | 1254.3 MB/s | 4188.4 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 907.6 MB/s | 2441.1 MB/s | **2.7x** | 778.1 MB/s | 4524.1 MB/s | **5.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 292.3 MB/s | 485.1 MB/s | **1.7x** | 864.9 MB/s | 3120.9 MB/s | **3.6x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 292.8 MB/s | 547.4 MB/s | **1.9x** | 650.3 MB/s | 3133.0 MB/s | **4.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 655.0 MB/s | 1696.1 MB/s | **2.6x** | 957.2 MB/s | 6346.5 MB/s | **6.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 623.9 MB/s | 1503.9 MB/s | **2.4x** | 947.8 MB/s | 4529.4 MB/s | **4.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 74.8 MB/s | 1177.2 MB/s | **15.7x** | 868.7 MB/s | 6821.7 MB/s | **7.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 73.8 MB/s | 1150.7 MB/s | **15.6x** | 923.0 MB/s | 4551.2 MB/s | **4.9x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1519.7 MB/s | 7549.4 MB/s | **5.0x** | 1579.3 MB/s | 4263.2 MB/s | **2.7x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1150.6 MB/s | 5301.9 MB/s | **4.6x** | 1439.2 MB/s | 4668.0 MB/s | **3.2x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 736.3 MB/s | 4554.6 MB/s | **6.2x** | 828.4 MB/s | 4686.3 MB/s | **5.7x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 754.6 MB/s | 4403.6 MB/s | **5.8x** | 932.8 MB/s | 2116.6 MB/s | **2.3x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 209.6 MB/s | 4102.2 MB/s | **19.6x** | 4407.2 MB/s | 4198.2 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 201.7 MB/s | 1264.2 MB/s | **6.3x** | 3231.8 MB/s | 3698.0 MB/s | **1.1x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 145.2 MB/s | 5455.2 MB/s | **37.6x** | 1656.9 MB/s | 4371.7 MB/s | **2.6x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 143.8 MB/s | 1315.5 MB/s | **9.1x** | 1378.8 MB/s | 5082.5 MB/s | **3.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 87.9 MB/s | 179.5 MB/s | **2.0x** | 3153.7 MB/s | 11190.0 MB/s | **3.5x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 81.0 MB/s | 175.7 MB/s | **2.2x** | 1820.8 MB/s | 2256.0 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 74.0 MB/s | 146.5 MB/s | **2.0x** | 3894.8 MB/s | 11526.3 MB/s | **3.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 68.8 MB/s | 139.5 MB/s | **2.0x** | 1792.9 MB/s | 2368.1 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5544.7 MB/s | 5031.3 MB/s | **0.9x** | 6112.1 MB/s | 3925.1 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 5742.3 MB/s | 4748.7 MB/s | **0.8x** | 6236.1 MB/s | 3083.8 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 995.4 MB/s | 1752.1 MB/s | **1.8x** | 1661.8 MB/s | 5101.6 MB/s | **3.1x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 972.6 MB/s | 1750.9 MB/s | **1.8x** | 1687.2 MB/s | 5791.2 MB/s | **3.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.11 MB (0.0%) | 5022.0 MB/s | 4906.6 MB/s | **1.0x** | 5282.5 MB/s | 3676.8 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.11 MB (0.0%) | 5492.6 MB/s | 4784.4 MB/s | **0.9x** | 5222.8 MB/s | 5227.0 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 682.0 MB/s | 4638.1 MB/s | **6.8x** | 3803.5 MB/s | 4960.4 MB/s | **1.3x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 680.3 MB/s | 4600.4 MB/s | **6.8x** | 3570.2 MB/s | 5354.8 MB/s | **1.5x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1035.3 MB/s | 1831.3 MB/s | **1.8x** | 1689.9 MB/s | 10638.7 MB/s | **6.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 989.9 MB/s | 1844.6 MB/s | **1.9x** | 2031.7 MB/s | 10717.5 MB/s | **5.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.1 MB/s | 1253.6 MB/s | **13.3x** | 1701.3 MB/s | 12435.9 MB/s | **7.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.6 MB/s | 1249.1 MB/s | **13.2x** | 1869.3 MB/s | 12061.4 MB/s | **6.5x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 13052.4 MB/s | 18131.2 MB/s | **1.4x** | 5819.0 MB/s | 4314.5 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10350.9 MB/s | 17940.6 MB/s | **1.7x** | 6339.4 MB/s | 5458.3 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2175.5 MB/s | 8748.5 MB/s | **4.0x** | 1888.4 MB/s | 3100.0 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2029.0 MB/s | 10887.1 MB/s | **5.4x** | 1805.7 MB/s | 3192.4 MB/s | **1.8x** | - |
