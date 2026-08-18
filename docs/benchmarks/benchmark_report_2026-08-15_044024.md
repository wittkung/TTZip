# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 20:40:24 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 884.9 MB/s | 887.5 MB/s | **1.0x** | 701.9 MB/s | 1529.5 MB/s | **2.2x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 807.3 MB/s | 928.6 MB/s | **1.2x** | 569.1 MB/s | 1629.1 MB/s | **2.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 291.1 MB/s | 415.6 MB/s | **1.4x** | 590.0 MB/s | 1417.9 MB/s | **2.4x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 287.1 MB/s | 430.5 MB/s | **1.5x** | 488.6 MB/s | 1450.6 MB/s | **3.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 453.4 MB/s | 1202.6 MB/s | **2.7x** | 601.5 MB/s | 2234.7 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 420.1 MB/s | 921.1 MB/s | **2.2x** | 297.7 MB/s | 1909.1 MB/s | **6.4x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 365.9 MB/s | 1198.6 MB/s | **3.3x** | 594.0 MB/s | 2217.3 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 349.7 MB/s | 892.9 MB/s | **2.6x** | 294.2 MB/s | 1855.5 MB/s | **6.3x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 241.1 MB/s | 985.2 MB/s | **4.1x** | 279.9 MB/s | 1061.6 MB/s | **3.8x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 241.0 MB/s | 1003.3 MB/s | **4.2x** | 248.0 MB/s | 1048.0 MB/s | **4.2x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 865.4 MB/s | 1865.6 MB/s | **2.2x** | 1111.3 MB/s | 3201.8 MB/s | **2.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 760.0 MB/s | 2655.8 MB/s | **3.5x** | 700.9 MB/s | 5181.8 MB/s | **7.4x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 281.9 MB/s | 484.9 MB/s | **1.7x** | 883.1 MB/s | 3197.6 MB/s | **3.6x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 280.0 MB/s | 486.2 MB/s | **1.7x** | 587.2 MB/s | 2766.4 MB/s | **4.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 608.7 MB/s | 1727.8 MB/s | **2.8x** | 922.1 MB/s | 6044.5 MB/s | **6.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 595.4 MB/s | 1498.1 MB/s | **2.5x** | 980.2 MB/s | 4001.7 MB/s | **4.1x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 80.6 MB/s | 1241.7 MB/s | **15.4x** | 788.5 MB/s | 5492.9 MB/s | **7.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 80.2 MB/s | 1159.6 MB/s | **14.5x** | 894.6 MB/s | 4414.1 MB/s | **4.9x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1433.2 MB/s | 4681.9 MB/s | **3.3x** | 1382.5 MB/s | 4760.1 MB/s | **3.4x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1093.0 MB/s | 4307.7 MB/s | **3.9x** | 1384.2 MB/s | 4685.7 MB/s | **3.4x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.7%) | 0.03 MB (0.4%) | 709.9 MB/s | 4624.8 MB/s | **6.5x** | 865.1 MB/s | 5165.7 MB/s | **6.0x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 663.9 MB/s | 4222.1 MB/s | **6.4x** | 853.1 MB/s | 5001.5 MB/s | **5.9x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 228.3 MB/s | 5151.1 MB/s | **22.6x** | 4088.6 MB/s | 6251.1 MB/s | **1.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 216.8 MB/s | 1338.3 MB/s | **6.2x** | 3119.6 MB/s | 7789.7 MB/s | **2.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 145.1 MB/s | 5132.6 MB/s | **35.4x** | 1665.1 MB/s | 5864.3 MB/s | **3.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 147.7 MB/s | 1335.9 MB/s | **9.0x** | 1526.2 MB/s | 7582.1 MB/s | **5.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 87.7 MB/s | 181.2 MB/s | **2.1x** | 3809.3 MB/s | 10259.0 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 81.7 MB/s | 162.3 MB/s | **2.0x** | 1830.2 MB/s | 2240.0 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 74.6 MB/s | 148.1 MB/s | **2.0x** | 3569.3 MB/s | 10743.4 MB/s | **3.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 68.4 MB/s | 140.4 MB/s | **2.1x** | 1751.8 MB/s | 2343.2 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5782.5 MB/s | 4889.2 MB/s | **0.8x** | 6807.4 MB/s | 3798.3 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 5913.0 MB/s | 4958.2 MB/s | **0.8x** | 7250.5 MB/s | 3900.2 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 1041.6 MB/s | 1788.1 MB/s | **1.7x** | 1675.0 MB/s | 5362.1 MB/s | **3.2x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 972.8 MB/s | 1783.2 MB/s | **1.8x** | 1522.9 MB/s | 5134.7 MB/s | **3.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5097.0 MB/s | 4912.3 MB/s | **1.0x** | 5703.8 MB/s | 9844.4 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 4967.2 MB/s | 5020.9 MB/s | **1.0x** | 5244.8 MB/s | 9846.3 MB/s | **1.9x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 664.3 MB/s | 4452.4 MB/s | **6.7x** | 3827.7 MB/s | 9380.3 MB/s | **2.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 662.6 MB/s | 4514.7 MB/s | **6.8x** | 3558.1 MB/s | 9607.9 MB/s | **2.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1014.3 MB/s | 1815.4 MB/s | **1.8x** | 1690.7 MB/s | 10556.3 MB/s | **6.2x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1001.9 MB/s | 1812.1 MB/s | **1.8x** | 2008.8 MB/s | 10131.2 MB/s | **5.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 92.3 MB/s | 1234.6 MB/s | **13.4x** | 1665.1 MB/s | 11936.9 MB/s | **7.2x** | - |
