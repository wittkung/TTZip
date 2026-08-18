# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 04:36:03 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 941.6 MB/s | 398.8 MB/s | **0.4x** | 789.8 MB/s | 655.4 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 937.6 MB/s | 252.0 MB/s | **0.3x** | 608.9 MB/s | 502.9 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 296.9 MB/s | 440.5 MB/s | **1.5x** | 658.4 MB/s | 793.6 MB/s | **1.2x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 297.1 MB/s | 251.9 MB/s | **0.8x** | 514.4 MB/s | 500.8 MB/s | **1.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 541.6 MB/s | 1316.9 MB/s | **2.4x** | 615.5 MB/s | 2263.7 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 502.7 MB/s | 967.1 MB/s | **1.9x** | 316.1 MB/s | 1842.5 MB/s | **5.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 426.4 MB/s | 1291.3 MB/s | **3.0x** | 612.4 MB/s | 2272.0 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 412.6 MB/s | 954.9 MB/s | **2.3x** | 317.4 MB/s | 1941.2 MB/s | **6.1x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 293.2 MB/s | 1144.1 MB/s | **3.9x** | 272.9 MB/s | 1013.9 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 226.0 MB/s | 1140.8 MB/s | **5.0x** | 252.4 MB/s | 952.8 MB/s | **3.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1080.8 MB/s | 554.2 MB/s | **0.5x** | 1530.0 MB/s | 1951.5 MB/s | **1.3x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1003.2 MB/s | 299.6 MB/s | **0.3x** | 874.8 MB/s | 707.4 MB/s | **0.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 294.4 MB/s | 559.3 MB/s | **1.9x** | 1093.9 MB/s | 1926.4 MB/s | **1.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 303.0 MB/s | 301.0 MB/s | **1.0x** | 736.0 MB/s | 718.8 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 707.1 MB/s | 1850.7 MB/s | **2.6x** | 1136.4 MB/s | 6957.4 MB/s | **6.1x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 685.9 MB/s | 1676.9 MB/s | **2.4x** | 1218.7 MB/s | 5327.1 MB/s | **4.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 82.0 MB/s | 1292.2 MB/s | **15.8x** | 1006.1 MB/s | 8023.2 MB/s | **8.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 80.9 MB/s | 1210.7 MB/s | **15.0x** | 1128.3 MB/s | 5720.0 MB/s | **5.1x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1793.1 MB/s | 5016.2 MB/s | **2.8x** | 1899.4 MB/s | 5328.9 MB/s | **2.8x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1376.6 MB/s | 4795.7 MB/s | **3.5x** | 1762.6 MB/s | 5168.7 MB/s | **2.9x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 819.8 MB/s | 4602.3 MB/s | **5.6x** | 1010.2 MB/s | 6106.7 MB/s | **6.0x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 833.3 MB/s | 4575.6 MB/s | **5.5x** | 978.4 MB/s | 6139.6 MB/s | **6.3x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 249.4 MB/s | 4700.1 MB/s | **18.8x** | 4555.1 MB/s | 8116.3 MB/s | **1.8x** | 2_SolidBuf_IO_and_CRC32 (94.2%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 245.1 MB/s | 201.6 MB/s | **0.8x** | 3521.7 MB/s | 1624.2 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 151.9 MB/s | 4484.1 MB/s | **29.5x** | 1664.3 MB/s | 8154.8 MB/s | **4.9x** | 2_SolidBuf_IO_and_CRC32 (93.5%) |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 153.9 MB/s | 198.3 MB/s | **1.3x** | 1606.0 MB/s | 1519.4 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 90.4 MB/s | 190.5 MB/s | **2.1x** | 3794.2 MB/s | 11747.3 MB/s | **3.1x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 85.6 MB/s | 176.5 MB/s | **2.1x** | 1967.0 MB/s | 2454.0 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 76.9 MB/s | 149.6 MB/s | **1.9x** | 4327.1 MB/s | 12091.8 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 73.0 MB/s | 144.5 MB/s | **2.0x** | 1980.7 MB/s | 2489.2 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 1.02 MB (1.0%) | 6388.5 MB/s | 6416.7 MB/s | **1.0x** | 7110.0 MB/s | 7353.6 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.02 MB (1.0%) | 6435.7 MB/s | 6212.6 MB/s | **1.0x** | 7477.2 MB/s | 7351.2 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 1042.4 MB/s | 1789.7 MB/s | **1.7x** | 1745.3 MB/s | 6168.8 MB/s | **3.5x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 1026.0 MB/s | 1827.5 MB/s | **1.8x** | 1733.1 MB/s | 6038.3 MB/s | **3.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5403.0 MB/s | 4780.5 MB/s | **0.9x** | 6218.8 MB/s | 2137.3 MB/s | **0.3x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5391.2 MB/s | 686.1 MB/s | **0.1x** | 5760.1 MB/s | 3881.2 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 687.3 MB/s | 4776.5 MB/s | **7.0x** | 4063.9 MB/s | 2162.6 MB/s | **0.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 693.0 MB/s | 683.5 MB/s | **1.0x** | 3894.3 MB/s | 3840.4 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1058.7 MB/s | 1882.5 MB/s | **1.8x** | 1857.5 MB/s | 7287.2 MB/s | **3.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1058.1 MB/s | 1877.4 MB/s | **1.8x** | 2201.5 MB/s | 7753.2 MB/s | **3.5x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 98.1 MB/s | 1284.0 MB/s | **13.1x** | 1851.5 MB/s | 12721.9 MB/s | **6.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 99.6 MB/s | 1282.8 MB/s | **12.9x** | 2193.9 MB/s | 12520.5 MB/s | **5.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 15820.1 MB/s | 4677.1 MB/s | **0.3x** | 6849.0 MB/s | 8077.6 MB/s | **1.2x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10729.2 MB/s | 4737.9 MB/s | **0.4x** | 7330.0 MB/s | 7980.0 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2198.4 MB/s | 9508.9 MB/s | **4.3x** | 1960.9 MB/s | 3368.6 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2058.2 MB/s | 9552.2 MB/s | **4.6x** | 1986.8 MB/s | 3369.5 MB/s | **1.7x** | - |
