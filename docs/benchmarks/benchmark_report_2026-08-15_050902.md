# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 21:09:02 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 893.5 MB/s | 901.1 MB/s | **1.0x** | 742.4 MB/s | 1414.7 MB/s | **1.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 860.3 MB/s | 918.0 MB/s | **1.1x** | 546.1 MB/s | 1485.2 MB/s | **2.7x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 294.7 MB/s | 418.7 MB/s | **1.4x** | 593.1 MB/s | 1402.0 MB/s | **2.4x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 290.9 MB/s | 431.5 MB/s | **1.5x** | 497.5 MB/s | 1262.7 MB/s | **2.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 490.7 MB/s | 1230.8 MB/s | **2.5x** | 586.9 MB/s | 2105.5 MB/s | **3.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 465.2 MB/s | 907.0 MB/s | **1.9x** | 181.2 MB/s | 1925.6 MB/s | **10.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 393.8 MB/s | 1180.8 MB/s | **3.0x** | 584.9 MB/s | 1999.8 MB/s | **3.4x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 375.9 MB/s | 936.6 MB/s | **2.5x** | 297.8 MB/s | 1910.2 MB/s | **6.4x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 292.2 MB/s | 1015.8 MB/s | **3.5x** | 287.5 MB/s | 1093.5 MB/s | **3.8x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 295.6 MB/s | 980.9 MB/s | **3.3x** | 279.8 MB/s | 1089.1 MB/s | **3.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1083.2 MB/s | 2799.3 MB/s | **2.6x** | 1407.0 MB/s | 5495.0 MB/s | **3.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 930.7 MB/s | 2781.2 MB/s | **3.0x** | 833.5 MB/s | 5546.8 MB/s | **6.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 297.5 MB/s | 553.6 MB/s | **1.9x** | 989.7 MB/s | 3850.8 MB/s | **3.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 294.4 MB/s | 549.9 MB/s | **1.9x** | 670.8 MB/s | 3887.3 MB/s | **5.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 669.3 MB/s | 1779.2 MB/s | **2.7x** | 991.4 MB/s | 6395.0 MB/s | **6.5x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 327.6 MB/s | 1627.4 MB/s | **5.0x** | 675.0 MB/s | 4992.4 MB/s | **7.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 77.1 MB/s | 1243.2 MB/s | **16.1x** | 953.7 MB/s | 6991.4 MB/s | **7.3x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 77.6 MB/s | 1170.6 MB/s | **15.1x** | 1025.7 MB/s | 5237.6 MB/s | **5.1x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1623.8 MB/s | 8725.7 MB/s | **5.4x** | 1714.6 MB/s | 4968.3 MB/s | **2.9x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1173.8 MB/s | 6063.3 MB/s | **5.2x** | 1479.9 MB/s | 5138.5 MB/s | **3.5x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 790.7 MB/s | 4911.2 MB/s | **6.2x** | 956.8 MB/s | 6023.1 MB/s | **6.3x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 769.0 MB/s | 5451.1 MB/s | **7.1x** | 966.9 MB/s | 5990.3 MB/s | **6.2x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 204.6 MB/s | 5520.3 MB/s | **27.0x** | 4276.4 MB/s | 6710.3 MB/s | **1.6x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 204.3 MB/s | 1287.0 MB/s | **6.3x** | 3143.3 MB/s | 7426.1 MB/s | **2.4x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 142.2 MB/s | 5540.0 MB/s | **39.0x** | 1681.2 MB/s | 6891.4 MB/s | **4.1x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 132.1 MB/s | 1365.6 MB/s | **10.3x** | 1451.0 MB/s | 7996.2 MB/s | **5.5x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 88.5 MB/s | 174.9 MB/s | **2.0x** | 3704.6 MB/s | 10663.8 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 80.0 MB/s | 172.1 MB/s | **2.2x** | 1779.2 MB/s | 2354.4 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 74.7 MB/s | 145.4 MB/s | **1.9x** | 3857.5 MB/s | 10819.4 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.2 MB/s | 139.9 MB/s | **2.0x** | 1855.7 MB/s | 2357.9 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4867.1 MB/s | 4695.4 MB/s | **1.0x** | 5464.2 MB/s | 3801.9 MB/s | **0.7x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 5699.7 MB/s | 5227.7 MB/s | **0.9x** | 7198.0 MB/s | 4534.7 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 862.4 MB/s | 1748.9 MB/s | **2.0x** | 953.2 MB/s | 5731.9 MB/s | **6.0x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 984.0 MB/s | 1773.3 MB/s | **1.8x** | 1582.9 MB/s | 5117.9 MB/s | **3.2x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5306.9 MB/s | 4685.9 MB/s | **0.9x** | 5353.2 MB/s | 8337.3 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5386.8 MB/s | 4709.4 MB/s | **0.9x** | 5187.8 MB/s | 8733.2 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 671.7 MB/s | 4731.4 MB/s | **7.0x** | 3692.5 MB/s | 9860.3 MB/s | **2.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 674.0 MB/s | 4768.7 MB/s | **7.1x** | 3282.6 MB/s | 9866.6 MB/s | **3.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1024.1 MB/s | 1840.7 MB/s | **1.8x** | 1688.5 MB/s | 10629.3 MB/s | **6.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1007.7 MB/s | 1846.4 MB/s | **1.8x** | 1940.0 MB/s | 9721.0 MB/s | **5.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.4 MB/s | 1257.6 MB/s | **13.3x** | 1591.5 MB/s | 11677.8 MB/s | **7.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.6 MB/s | 1252.2 MB/s | **13.2x** | 1999.9 MB/s | 11571.5 MB/s | **5.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 12944.7 MB/s | 21173.5 MB/s | **1.6x** | 5611.5 MB/s | 4530.3 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 9419.4 MB/s | 22153.1 MB/s | **2.4x** | 5559.5 MB/s | 4588.5 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2089.0 MB/s | 11158.4 MB/s | **5.3x** | 1904.3 MB/s | 3147.5 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2068.2 MB/s | 11191.4 MB/s | **5.4x** | 1899.7 MB/s | 3121.2 MB/s | **1.6x** | - |
