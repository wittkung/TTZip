# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 04:09:06 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 893.5 MB/s | 401.7 MB/s | **0.4x** | 692.8 MB/s | 519.0 MB/s | **0.7x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 878.0 MB/s | 240.6 MB/s | **0.3x** | 568.3 MB/s | 477.6 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 290.4 MB/s | 431.8 MB/s | **1.5x** | 631.3 MB/s | 660.2 MB/s | **1.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 284.2 MB/s | 242.5 MB/s | **0.9x** | 503.0 MB/s | 458.4 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 438.7 MB/s | 1254.2 MB/s | **2.9x** | 610.0 MB/s | 1759.6 MB/s | **2.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 409.6 MB/s | 899.1 MB/s | **2.2x** | 311.5 MB/s | 1931.4 MB/s | **6.2x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 361.0 MB/s | 1271.7 MB/s | **3.5x** | 598.1 MB/s | 2066.5 MB/s | **3.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 338.2 MB/s | 916.3 MB/s | **2.7x** | 297.5 MB/s | 1872.5 MB/s | **6.3x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 264.0 MB/s | 417.5 MB/s | **1.6x** | 264.6 MB/s | 945.4 MB/s | **3.6x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 283.9 MB/s | 413.7 MB/s | **1.5x** | 263.1 MB/s | 962.2 MB/s | **3.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1052.9 MB/s | 554.3 MB/s | **0.5x** | 1396.3 MB/s | 1836.5 MB/s | **1.3x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 940.0 MB/s | 282.4 MB/s | **0.3x** | 846.8 MB/s | 664.5 MB/s | **0.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 288.1 MB/s | 550.6 MB/s | **1.9x** | 999.1 MB/s | 1847.8 MB/s | **1.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 284.2 MB/s | 282.2 MB/s | **1.0x** | 679.3 MB/s | 653.5 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 662.8 MB/s | 1756.8 MB/s | **2.7x** | 988.7 MB/s | 696.4 MB/s | **0.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 652.4 MB/s | 1610.2 MB/s | **2.5x** | 1069.4 MB/s | 4660.8 MB/s | **4.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 80.9 MB/s | 1251.3 MB/s | **15.5x** | 981.7 MB/s | 6163.2 MB/s | **6.3x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 79.1 MB/s | 1171.6 MB/s | **14.8x** | 1031.5 MB/s | 4987.8 MB/s | **4.8x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1288.6 MB/s | 1677.5 MB/s | **1.3x** | 1634.6 MB/s | 5699.2 MB/s | **3.5x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1284.5 MB/s | 1442.7 MB/s | **1.1x** | 1593.7 MB/s | 6067.4 MB/s | **3.8x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.3%) | 767.3 MB/s | 603.6 MB/s | **0.8x** | 916.8 MB/s | 5655.9 MB/s | **6.2x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 748.0 MB/s | 603.2 MB/s | **0.8x** | 930.2 MB/s | 5698.7 MB/s | **6.1x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 213.8 MB/s | 4258.1 MB/s | **19.9x** | 4228.4 MB/s | 7349.3 MB/s | **1.7x** | 2_SolidBuf_IO_and_CRC32 (92.0%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 200.9 MB/s | 189.3 MB/s | **0.9x** | 3316.6 MB/s | 1588.0 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 139.6 MB/s | 4172.2 MB/s | **29.9x** | 1727.3 MB/s | 6785.0 MB/s | **3.9x** | 2_SolidBuf_IO_and_CRC32 (93.2%) |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 141.4 MB/s | 190.2 MB/s | **1.3x** | 1589.2 MB/s | 1576.2 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 88.6 MB/s | 191.0 MB/s | **2.2x** | 3921.2 MB/s | 10312.7 MB/s | **2.6x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 79.4 MB/s | 179.8 MB/s | **2.3x** | 1876.4 MB/s | 2424.3 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 74.6 MB/s | 148.8 MB/s | **2.0x** | 3978.5 MB/s | 10120.8 MB/s | **2.5x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 71.5 MB/s | 142.6 MB/s | **2.0x** | 1884.3 MB/s | 2406.6 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5326.6 MB/s | 1461.8 MB/s | **0.3x** | 5226.3 MB/s | 5533.7 MB/s | **1.1x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 6274.1 MB/s | 1509.5 MB/s | **0.2x** | 7285.6 MB/s | 8633.8 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 988.1 MB/s | 79.4 MB/s | **0.1x** | 1667.5 MB/s | 5450.1 MB/s | **3.3x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 971.5 MB/s | 79.3 MB/s | **0.1x** | 1589.0 MB/s | 5551.9 MB/s | **3.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5300.0 MB/s | 4661.5 MB/s | **0.9x** | 4982.9 MB/s | 2069.2 MB/s | **0.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5253.4 MB/s | 668.2 MB/s | **0.1x** | 5058.4 MB/s | 3435.3 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 671.6 MB/s | 4487.1 MB/s | **6.7x** | 3800.9 MB/s | 2083.8 MB/s | **0.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 668.5 MB/s | 665.3 MB/s | **1.0x** | 3427.9 MB/s | 3491.7 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1044.9 MB/s | 1848.0 MB/s | **1.8x** | 1796.4 MB/s | 6754.8 MB/s | **3.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1042.0 MB/s | 1866.3 MB/s | **1.8x** | 2073.0 MB/s | 7021.9 MB/s | **3.4x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 97.9 MB/s | 1263.1 MB/s | **12.9x** | 1769.0 MB/s | 10719.6 MB/s | **6.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.3 MB/s | 1257.6 MB/s | **13.3x** | 2032.9 MB/s | 10872.2 MB/s | **5.3x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 13867.7 MB/s | 1699.6 MB/s | **0.1x** | 5747.7 MB/s | 7434.1 MB/s | **1.3x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10613.9 MB/s | 1163.0 MB/s | **0.1x** | 5717.5 MB/s | 9245.4 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 1957.0 MB/s | 601.4 MB/s | **0.3x** | 1695.6 MB/s | 3212.9 MB/s | **1.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 1915.8 MB/s | 602.9 MB/s | **0.3x** | 1918.4 MB/s | 3268.8 MB/s | **1.7x** | - |
