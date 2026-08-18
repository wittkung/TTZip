# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 22:00:38 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 864.1 MB/s | 1492.8 MB/s | **1.7x** | 669.3 MB/s | 1451.1 MB/s | **2.2x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 831.2 MB/s | 1547.6 MB/s | **1.9x** | 529.9 MB/s | 1303.4 MB/s | **2.5x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 290.8 MB/s | 590.9 MB/s | **2.0x** | 612.0 MB/s | 1386.9 MB/s | **2.3x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 287.9 MB/s | 624.5 MB/s | **2.2x** | 444.3 MB/s | 1346.0 MB/s | **3.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 421.1 MB/s | 1120.1 MB/s | **2.7x** | 554.1 MB/s | 2038.1 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 405.1 MB/s | 842.2 MB/s | **2.1x** | 283.5 MB/s | 1859.2 MB/s | **6.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 348.9 MB/s | 1108.7 MB/s | **3.2x** | 520.4 MB/s | 2079.8 MB/s | **4.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 328.0 MB/s | 798.9 MB/s | **2.4x** | 233.0 MB/s | 1795.7 MB/s | **7.7x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 249.0 MB/s | 893.6 MB/s | **3.6x** | 258.4 MB/s | 941.3 MB/s | **3.6x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 274.1 MB/s | 1030.7 MB/s | **3.8x** | 261.4 MB/s | 1107.0 MB/s | **4.2x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 994.3 MB/s | 1840.6 MB/s | **1.9x** | 1307.8 MB/s | 4486.2 MB/s | **3.4x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 849.1 MB/s | 1834.6 MB/s | **2.2x** | 799.6 MB/s | 4390.7 MB/s | **5.5x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 296.4 MB/s | 572.9 MB/s | **1.9x** | 950.3 MB/s | 3773.9 MB/s | **4.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 294.8 MB/s | 571.4 MB/s | **1.9x** | 634.3 MB/s | 3750.1 MB/s | **5.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 654.9 MB/s | 1727.2 MB/s | **2.6x** | 950.3 MB/s | 6078.2 MB/s | **6.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 631.4 MB/s | 1605.8 MB/s | **2.5x** | 757.4 MB/s | 4635.3 MB/s | **6.1x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 78.0 MB/s | 1262.2 MB/s | **16.2x** | 951.0 MB/s | 6707.2 MB/s | **7.1x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 76.8 MB/s | 1177.1 MB/s | **15.3x** | 1012.4 MB/s | 5011.2 MB/s | **4.9x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1648.3 MB/s | 9460.3 MB/s | **5.7x** | 1661.0 MB/s | 5075.6 MB/s | **3.1x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1286.6 MB/s | 6049.2 MB/s | **4.7x** | 1568.4 MB/s | 5281.3 MB/s | **3.4x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 771.6 MB/s | 4625.4 MB/s | **6.0x** | 936.9 MB/s | 5465.1 MB/s | **5.8x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 781.8 MB/s | 5071.1 MB/s | **6.5x** | 962.1 MB/s | 5684.4 MB/s | **5.9x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 203.0 MB/s | 5539.7 MB/s | **27.3x** | 3467.8 MB/s | 6834.5 MB/s | **2.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 207.6 MB/s | 1326.0 MB/s | **6.4x** | 3143.2 MB/s | 7787.6 MB/s | **2.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 140.7 MB/s | 5098.5 MB/s | **36.2x** | 1672.6 MB/s | 6868.8 MB/s | **4.1x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 140.1 MB/s | 1414.2 MB/s | **10.1x** | 1437.9 MB/s | 8252.9 MB/s | **5.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 90.0 MB/s | 188.1 MB/s | **2.1x** | 3714.8 MB/s | 10058.8 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 83.8 MB/s | 175.8 MB/s | **2.1x** | 1810.3 MB/s | 2289.9 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 75.6 MB/s | 148.1 MB/s | **2.0x** | 3751.9 MB/s | 10139.5 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 71.1 MB/s | 141.9 MB/s | **2.0x** | 1823.3 MB/s | 2329.2 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5469.3 MB/s | 5126.1 MB/s | **0.9x** | 6894.9 MB/s | 3670.2 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 5774.3 MB/s | 5528.1 MB/s | **1.0x** | 7126.3 MB/s | 4424.1 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 1011.5 MB/s | 1784.6 MB/s | **1.8x** | 1525.9 MB/s | 5187.2 MB/s | **3.4x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 973.5 MB/s | 1780.2 MB/s | **1.8x** | 1638.8 MB/s | 5199.8 MB/s | **3.2x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5143.8 MB/s | 5197.1 MB/s | **1.0x** | 5610.6 MB/s | 8919.1 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5178.1 MB/s | 5452.5 MB/s | **1.1x** | 5312.0 MB/s | 9650.1 MB/s | **1.8x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 674.5 MB/s | 4903.6 MB/s | **7.3x** | 3636.9 MB/s | 9589.4 MB/s | **2.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 623.6 MB/s | 4977.9 MB/s | **8.0x** | 3466.1 MB/s | 9451.7 MB/s | **2.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1017.2 MB/s | 1830.1 MB/s | **1.8x** | 1719.4 MB/s | 10731.5 MB/s | **6.2x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1028.1 MB/s | 1868.6 MB/s | **1.8x** | 2105.7 MB/s | 10629.1 MB/s | **5.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 97.8 MB/s | 1264.2 MB/s | **12.9x** | 1750.9 MB/s | 11850.8 MB/s | **6.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 98.1 MB/s | 1264.7 MB/s | **12.9x** | 2112.9 MB/s | 11848.2 MB/s | **5.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 15006.8 MB/s | 20282.6 MB/s | **1.4x** | 5783.7 MB/s | 5198.6 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10389.9 MB/s | 20885.1 MB/s | **2.0x** | 5920.4 MB/s | 6117.3 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2196.1 MB/s | 10900.1 MB/s | **5.0x** | 1946.5 MB/s | 3192.9 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2077.1 MB/s | 10671.8 MB/s | **5.1x** | 1995.0 MB/s | 3169.6 MB/s | **1.6x** | - |
