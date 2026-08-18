# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 17:39:49 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 915.0 MB/s | 806.9 MB/s | **0.9x** | 726.7 MB/s | 1328.8 MB/s | **1.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 844.8 MB/s | 631.3 MB/s | **0.7x** | 531.0 MB/s | 777.0 MB/s | **1.5x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 291.1 MB/s | 413.4 MB/s | **1.4x** | 615.7 MB/s | 1223.0 MB/s | **2.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 289.9 MB/s | 352.8 MB/s | **1.2x** | 483.1 MB/s | 761.0 MB/s | **1.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 473.5 MB/s | 1247.8 MB/s | **2.6x** | 603.5 MB/s | 2106.1 MB/s | **3.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 446.4 MB/s | 863.7 MB/s | **1.9x** | 282.8 MB/s | 1862.1 MB/s | **6.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 363.3 MB/s | 1121.5 MB/s | **3.1x** | 600.9 MB/s | 1957.0 MB/s | **3.3x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 351.1 MB/s | 928.0 MB/s | **2.6x** | 292.9 MB/s | 1933.6 MB/s | **6.6x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 283.1 MB/s | 1056.8 MB/s | **3.7x** | 280.5 MB/s | 995.8 MB/s | **3.6x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 277.5 MB/s | 1065.3 MB/s | **3.8x** | 273.2 MB/s | 1023.8 MB/s | **3.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1053.5 MB/s | 2262.5 MB/s | **2.1x** | 1391.3 MB/s | 5591.9 MB/s | **4.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 936.6 MB/s | 1016.8 MB/s | **1.1x** | 843.9 MB/s | 1330.6 MB/s | **1.6x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 298.4 MB/s | 525.7 MB/s | **1.8x** | 971.8 MB/s | 3753.2 MB/s | **3.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 275.5 MB/s | 426.9 MB/s | **1.5x** | 528.7 MB/s | 1233.0 MB/s | **2.3x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 640.9 MB/s | 1620.6 MB/s | **2.5x** | 940.3 MB/s | 5818.3 MB/s | **6.2x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 642.0 MB/s | 1543.8 MB/s | **2.4x** | 1017.4 MB/s | 4924.1 MB/s | **4.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 76.0 MB/s | 1243.4 MB/s | **16.4x** | 955.6 MB/s | 6122.2 MB/s | **6.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 77.4 MB/s | 1181.4 MB/s | **15.3x** | 1019.2 MB/s | 5273.6 MB/s | **5.2x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1743.7 MB/s | 6759.9 MB/s | **3.9x** | 1676.8 MB/s | 5176.9 MB/s | **3.1x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1284.6 MB/s | 3957.2 MB/s | **3.1x** | 1671.7 MB/s | 6421.1 MB/s | **3.8x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 771.2 MB/s | 4754.7 MB/s | **6.2x** | 931.2 MB/s | 5994.9 MB/s | **6.4x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 770.2 MB/s | 4882.3 MB/s | **6.3x** | 951.9 MB/s | 5944.9 MB/s | **6.2x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 220.5 MB/s | 4807.3 MB/s | **21.8x** | 4074.8 MB/s | 7026.0 MB/s | **1.7x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 210.3 MB/s | 1159.8 MB/s | **5.5x** | 3398.2 MB/s | 5375.9 MB/s | **1.6x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 141.6 MB/s | 5457.3 MB/s | **38.5x** | 1691.5 MB/s | 6692.5 MB/s | **4.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 141.8 MB/s | 1198.8 MB/s | **8.5x** | 1513.9 MB/s | 5413.3 MB/s | **3.6x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 89.6 MB/s | 182.6 MB/s | **2.0x** | 4028.2 MB/s | 11151.9 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 82.5 MB/s | 176.6 MB/s | **2.1x** | 1882.0 MB/s | 2336.6 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 74.1 MB/s | 147.3 MB/s | **2.0x** | 3844.6 MB/s | 10948.2 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 69.6 MB/s | 137.8 MB/s | **2.0x** | 1875.4 MB/s | 2367.4 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5467.9 MB/s | 3983.1 MB/s | **0.7x** | 6945.4 MB/s | 6879.1 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 12.63 MB (12.6%) | 6084.0 MB/s | 9060.9 MB/s | **1.5x** | 6308.2 MB/s | 8836.1 MB/s | **1.4x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 703.1 MB/s | 1711.2 MB/s | **2.4x** | 1370.6 MB/s | 5720.1 MB/s | **4.2x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 842.7 MB/s | 1630.4 MB/s | **1.9x** | 1431.7 MB/s | 5477.5 MB/s | **3.8x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.10 MB (0.0%) | 5240.9 MB/s | 20436.0 MB/s | **3.9x** | 5389.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.10 MB (0.0%) | 4992.8 MB/s | 16219.7 MB/s | **3.2x** | 5052.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 671.2 MB/s | 19446.1 MB/s | **29.0x** | 3788.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 684.3 MB/s | 15512.8 MB/s | **22.7x** | 3589.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1037.1 MB/s | 1850.1 MB/s | **1.8x** | 1771.2 MB/s | 7301.4 MB/s | **4.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1027.7 MB/s | 1770.6 MB/s | **1.7x** | 2076.4 MB/s | 7127.1 MB/s | **3.4x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 95.4 MB/s | 1259.7 MB/s | **13.2x** | 1756.0 MB/s | 11520.8 MB/s | **6.6x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 95.2 MB/s | 1257.7 MB/s | **13.2x** | 2037.5 MB/s | 11574.5 MB/s | **5.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 14821.3 MB/s | 12858.1 MB/s | **0.9x** | 6033.7 MB/s | 7783.4 MB/s | **1.3x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10918.1 MB/s | 11627.4 MB/s | **1.1x** | 5746.0 MB/s | 8403.1 MB/s | **1.5x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2020.2 MB/s | 10486.6 MB/s | **5.2x** | 1602.8 MB/s | 3215.8 MB/s | **2.0x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 1955.6 MB/s | 10169.8 MB/s | **5.2x** | 1966.9 MB/s | 3173.9 MB/s | **1.6x** | - |
