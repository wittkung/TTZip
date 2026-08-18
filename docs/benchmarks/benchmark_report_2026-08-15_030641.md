# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 19:06:41 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 882.0 MB/s | 956.2 MB/s | **1.1x** | 724.0 MB/s | 1198.2 MB/s | **1.7x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 877.9 MB/s | 847.1 MB/s | **1.0x** | 547.5 MB/s | 840.7 MB/s | **1.5x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 291.6 MB/s | 421.5 MB/s | **1.4x** | 617.3 MB/s | 1294.8 MB/s | **2.1x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 291.0 MB/s | 442.5 MB/s | **1.5x** | 488.4 MB/s | 774.6 MB/s | **1.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 484.7 MB/s | 1333.4 MB/s | **2.8x** | 585.0 MB/s | 2078.3 MB/s | **3.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 466.8 MB/s | 955.1 MB/s | **2.0x** | 307.4 MB/s | 1898.4 MB/s | **6.2x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 409.8 MB/s | 1337.3 MB/s | **3.3x** | 581.4 MB/s | 2257.8 MB/s | **3.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 386.8 MB/s | 968.1 MB/s | **2.5x** | 304.8 MB/s | 1904.6 MB/s | **6.2x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 279.9 MB/s | 1113.9 MB/s | **4.0x** | 279.3 MB/s | 704.2 MB/s | **2.5x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 290.8 MB/s | 1119.3 MB/s | **3.8x** | 274.8 MB/s | 393.0 MB/s | **1.4x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1057.3 MB/s | 2484.0 MB/s | **2.3x** | 983.7 MB/s | 4642.8 MB/s | **4.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 967.2 MB/s | 520.7 MB/s | **0.5x** | 868.4 MB/s | 893.5 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 294.6 MB/s | 534.5 MB/s | **1.8x** | 1012.0 MB/s | 3531.3 MB/s | **3.5x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 289.0 MB/s | 571.4 MB/s | **2.0x** | 686.3 MB/s | 1198.1 MB/s | **1.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 681.8 MB/s | 1683.3 MB/s | **2.5x** | 1066.1 MB/s | 6232.4 MB/s | **5.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 670.0 MB/s | 1627.1 MB/s | **2.4x** | 1115.8 MB/s | 4779.9 MB/s | **4.3x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 78.0 MB/s | 1279.5 MB/s | **16.4x** | 971.7 MB/s | 6790.2 MB/s | **7.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 78.5 MB/s | 1198.4 MB/s | **15.3x** | 1036.1 MB/s | 5466.4 MB/s | **5.3x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1765.5 MB/s | 8367.4 MB/s | **4.7x** | 1820.4 MB/s | 5283.7 MB/s | **2.9x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1317.2 MB/s | 4309.9 MB/s | **3.3x** | 1602.4 MB/s | 4622.4 MB/s | **2.9x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 800.5 MB/s | 5096.4 MB/s | **6.4x** | 980.8 MB/s | 5778.7 MB/s | **5.9x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 776.9 MB/s | 5143.8 MB/s | **6.6x** | 979.5 MB/s | 5115.9 MB/s | **5.2x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 239.8 MB/s | 3699.9 MB/s | **15.4x** | 4214.6 MB/s | 3590.3 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 236.4 MB/s | 1184.8 MB/s | **5.0x** | 3355.1 MB/s | 3241.9 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 142.4 MB/s | 5085.4 MB/s | **35.7x** | 1641.6 MB/s | 4035.8 MB/s | **2.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 143.9 MB/s | 1297.7 MB/s | **9.0x** | 1484.6 MB/s | 3918.7 MB/s | **2.6x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 86.8 MB/s | 188.0 MB/s | **2.2x** | 3786.7 MB/s | 10380.4 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 84.3 MB/s | 176.8 MB/s | **2.1x** | 1909.8 MB/s | 2399.2 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 75.6 MB/s | 148.7 MB/s | **2.0x** | 3838.9 MB/s | 10420.0 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 72.0 MB/s | 142.8 MB/s | **2.0x** | 1826.9 MB/s | 2388.2 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5621.9 MB/s | 3648.5 MB/s | **0.6x** | 7099.0 MB/s | 4243.0 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 10.01 MB (10.0%) | 5455.6 MB/s | 14444.3 MB/s | **2.6x** | 7437.3 MB/s | 5480.7 MB/s | **0.7x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 1023.0 MB/s | 1482.0 MB/s | **1.4x** | 1618.7 MB/s | 4529.4 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 978.5 MB/s | 1742.2 MB/s | **1.8x** | 1680.7 MB/s | 5355.3 MB/s | **3.2x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.11 MB (0.0%) | 5402.6 MB/s | 5084.9 MB/s | **0.9x** | 5406.9 MB/s | 2839.9 MB/s | **0.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.11 MB (0.0%) | 5265.3 MB/s | 5142.4 MB/s | **1.0x** | 4880.8 MB/s | 4876.0 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 668.7 MB/s | 4318.1 MB/s | **6.5x** | 3643.4 MB/s | 3975.7 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 676.6 MB/s | 4557.4 MB/s | **6.7x** | 3436.6 MB/s | 4818.6 MB/s | **1.4x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1026.0 MB/s | 1860.2 MB/s | **1.8x** | 1497.3 MB/s | 10102.8 MB/s | **6.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1027.7 MB/s | 1840.4 MB/s | **1.8x** | 1903.7 MB/s | 8263.3 MB/s | **4.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 96.3 MB/s | 1241.1 MB/s | **12.9x** | 1711.5 MB/s | 9440.1 MB/s | **5.5x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 96.9 MB/s | 1264.8 MB/s | **13.1x** | 2071.3 MB/s | 11116.4 MB/s | **5.4x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 14983.4 MB/s | 18953.3 MB/s | **1.3x** | 6096.3 MB/s | 4682.6 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10044.6 MB/s | 20956.7 MB/s | **2.1x** | 6227.5 MB/s | 5353.4 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2007.6 MB/s | 10739.5 MB/s | **5.3x** | 1936.3 MB/s | 3295.8 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2037.6 MB/s | 11019.7 MB/s | **5.4x** | 1988.9 MB/s | 3232.8 MB/s | **1.6x** | - |
