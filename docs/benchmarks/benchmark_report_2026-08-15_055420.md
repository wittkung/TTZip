# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 21:54:20 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 846.9 MB/s | 2117.0 MB/s | **2.5x** | 709.6 MB/s | 1252.4 MB/s | **1.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 797.6 MB/s | 2309.6 MB/s | **2.9x** | 524.1 MB/s | 1427.9 MB/s | **2.7x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 290.8 MB/s | 549.1 MB/s | **1.9x** | 557.0 MB/s | 1279.2 MB/s | **2.3x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 291.4 MB/s | 579.1 MB/s | **2.0x** | 449.2 MB/s | 1253.5 MB/s | **2.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 447.3 MB/s | 1061.3 MB/s | **2.4x** | 360.4 MB/s | 1954.8 MB/s | **5.4x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 448.3 MB/s | 834.9 MB/s | **1.9x** | 273.1 MB/s | 1613.3 MB/s | **5.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 355.3 MB/s | 993.4 MB/s | **2.8x** | 512.0 MB/s | 1585.6 MB/s | **3.1x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 346.5 MB/s | 799.6 MB/s | **2.3x** | 293.7 MB/s | 1728.1 MB/s | **5.9x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 260.9 MB/s | 1027.8 MB/s | **3.9x** | 276.3 MB/s | 1030.5 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 259.9 MB/s | 1044.2 MB/s | **4.0x** | 270.4 MB/s | 1115.6 MB/s | **4.1x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 992.0 MB/s | 2478.6 MB/s | **2.5x** | 1359.8 MB/s | 4248.0 MB/s | **3.1x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 969.2 MB/s | 2646.7 MB/s | **2.7x** | 846.6 MB/s | 5470.9 MB/s | **6.5x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 297.6 MB/s | 555.5 MB/s | **1.9x** | 1021.2 MB/s | 3868.6 MB/s | **3.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 291.5 MB/s | 561.7 MB/s | **1.9x** | 685.0 MB/s | 3813.7 MB/s | **5.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 675.4 MB/s | 1776.7 MB/s | **2.6x** | 960.2 MB/s | 5384.7 MB/s | **5.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 651.5 MB/s | 1638.7 MB/s | **2.5x** | 1075.2 MB/s | 4806.3 MB/s | **4.5x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 79.7 MB/s | 1282.5 MB/s | **16.1x** | 962.0 MB/s | 6466.4 MB/s | **6.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 78.0 MB/s | 1098.6 MB/s | **14.1x** | 1035.8 MB/s | 4941.5 MB/s | **4.8x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1667.2 MB/s | 6274.1 MB/s | **3.8x** | 1686.6 MB/s | 5365.8 MB/s | **3.2x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1287.9 MB/s | 5462.0 MB/s | **4.2x** | 1316.9 MB/s | 5384.0 MB/s | **4.1x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 774.9 MB/s | 5026.0 MB/s | **6.5x** | 892.3 MB/s | 6164.4 MB/s | **6.9x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 768.2 MB/s | 5168.3 MB/s | **6.7x** | 923.5 MB/s | 6248.2 MB/s | **6.8x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 206.1 MB/s | 5487.5 MB/s | **26.6x** | 4290.7 MB/s | 5714.9 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 183.3 MB/s | 1403.2 MB/s | **7.7x** | 3232.9 MB/s | 7449.2 MB/s | **2.3x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 140.8 MB/s | 5741.3 MB/s | **40.8x** | 1734.5 MB/s | 6562.1 MB/s | **3.8x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 139.5 MB/s | 1386.8 MB/s | **9.9x** | 1560.9 MB/s | 6622.1 MB/s | **4.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 88.9 MB/s | 188.5 MB/s | **2.1x** | 3820.8 MB/s | 11287.5 MB/s | **3.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 84.1 MB/s | 178.0 MB/s | **2.1x** | 1899.0 MB/s | 2381.4 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 74.5 MB/s | 147.7 MB/s | **2.0x** | 4011.9 MB/s | 11164.7 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.9 MB/s | 142.4 MB/s | **2.0x** | 1868.1 MB/s | 2393.8 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5517.3 MB/s | 5270.0 MB/s | **1.0x** | 6747.9 MB/s | 3950.4 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 5757.8 MB/s | 5377.2 MB/s | **0.9x** | 6439.1 MB/s | 3890.5 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 836.2 MB/s | 1794.7 MB/s | **2.1x** | 1665.2 MB/s | 5475.3 MB/s | **3.3x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 972.9 MB/s | 1772.4 MB/s | **1.8x** | 1633.8 MB/s | 5678.6 MB/s | **3.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5092.1 MB/s | 5246.3 MB/s | **1.0x** | 5672.2 MB/s | 9039.5 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5152.1 MB/s | 5003.3 MB/s | **1.0x** | 5404.8 MB/s | 9206.5 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 668.8 MB/s | 4944.3 MB/s | **7.4x** | 3687.6 MB/s | 9736.8 MB/s | **2.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 665.3 MB/s | 4902.7 MB/s | **7.4x** | 3292.4 MB/s | 9492.5 MB/s | **2.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1020.4 MB/s | 1813.2 MB/s | **1.8x** | 1771.7 MB/s | 10364.9 MB/s | **5.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1001.7 MB/s | 1846.6 MB/s | **1.8x** | 2056.6 MB/s | 10580.9 MB/s | **5.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 95.3 MB/s | 1255.8 MB/s | **13.2x** | 1768.9 MB/s | 11686.1 MB/s | **6.6x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 95.8 MB/s | 1248.1 MB/s | **13.0x** | 2047.0 MB/s | 12129.0 MB/s | **5.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 15155.1 MB/s | 20329.5 MB/s | **1.3x** | 5980.4 MB/s | 4973.2 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10350.7 MB/s | 20489.0 MB/s | **2.0x** | 6031.4 MB/s | 6031.4 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2218.5 MB/s | 10499.4 MB/s | **4.7x** | 1946.3 MB/s | 3220.6 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2070.9 MB/s | 10845.8 MB/s | **5.2x** | 1999.5 MB/s | 3215.8 MB/s | **1.6x** | - |
