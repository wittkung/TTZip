# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 21:28:29 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 916.0 MB/s | 2327.2 MB/s | **2.5x** | 733.1 MB/s | 1272.7 MB/s | **1.7x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 882.5 MB/s | 2370.4 MB/s | **2.7x** | 586.3 MB/s | 1374.1 MB/s | **2.3x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 292.0 MB/s | 554.1 MB/s | **1.9x** | 602.1 MB/s | 1239.9 MB/s | **2.1x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 290.5 MB/s | 577.7 MB/s | **2.0x** | 506.3 MB/s | 1365.8 MB/s | **2.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 521.4 MB/s | 1259.0 MB/s | **2.4x** | 608.6 MB/s | 2126.4 MB/s | **3.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 467.1 MB/s | 926.5 MB/s | **2.0x** | 304.9 MB/s | 1836.0 MB/s | **6.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 409.6 MB/s | 1342.3 MB/s | **3.3x** | 597.9 MB/s | 2199.7 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 384.9 MB/s | 935.3 MB/s | **2.4x** | 304.3 MB/s | 1804.6 MB/s | **5.9x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 270.1 MB/s | 1068.5 MB/s | **4.0x** | 292.6 MB/s | 1133.4 MB/s | **3.9x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 281.9 MB/s | 1106.6 MB/s | **3.9x** | 292.3 MB/s | 1145.0 MB/s | **3.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1108.0 MB/s | 2714.6 MB/s | **2.4x** | 1455.1 MB/s | 5677.8 MB/s | **3.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 968.4 MB/s | 2612.9 MB/s | **2.7x** | 871.1 MB/s | 5986.8 MB/s | **6.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 295.4 MB/s | 556.0 MB/s | **1.9x** | 1027.3 MB/s | 4093.2 MB/s | **4.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 290.9 MB/s | 554.1 MB/s | **1.9x** | 689.1 MB/s | 4097.5 MB/s | **5.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 665.8 MB/s | 1837.8 MB/s | **2.8x** | 1050.1 MB/s | 6936.4 MB/s | **6.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 661.3 MB/s | 1699.1 MB/s | **2.6x** | 1138.3 MB/s | 5082.7 MB/s | **4.5x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 80.6 MB/s | 1153.7 MB/s | **14.3x** | 991.4 MB/s | 7637.9 MB/s | **7.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 81.0 MB/s | 1223.6 MB/s | **15.1x** | 1060.8 MB/s | 5692.6 MB/s | **5.4x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1717.9 MB/s | 8776.9 MB/s | **5.1x** | 1763.3 MB/s | 4555.9 MB/s | **2.6x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1276.7 MB/s | 6212.4 MB/s | **4.9x** | 1714.1 MB/s | 4609.2 MB/s | **2.7x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 805.3 MB/s | 5221.7 MB/s | **6.5x** | 964.9 MB/s | 6040.9 MB/s | **6.3x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 803.1 MB/s | 5168.9 MB/s | **6.4x** | 976.1 MB/s | 6123.9 MB/s | **6.3x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 239.4 MB/s | 5840.1 MB/s | **24.4x** | 4066.2 MB/s | 6914.0 MB/s | **1.7x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 237.2 MB/s | 1343.8 MB/s | **5.7x** | 3391.4 MB/s | 7402.7 MB/s | **2.2x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 151.6 MB/s | 5803.8 MB/s | **38.3x** | 1637.0 MB/s | 6633.5 MB/s | **4.1x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 151.4 MB/s | 1458.2 MB/s | **9.6x** | 1588.8 MB/s | 7978.8 MB/s | **5.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 90.0 MB/s | 188.9 MB/s | **2.1x** | 4072.5 MB/s | 11904.4 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 85.4 MB/s | 178.4 MB/s | **2.1x** | 1868.4 MB/s | 2436.1 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 75.9 MB/s | 152.0 MB/s | **2.0x** | 4038.3 MB/s | 11743.0 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 72.4 MB/s | 142.7 MB/s | **2.0x** | 1914.3 MB/s | 2392.7 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5364.2 MB/s | 5140.7 MB/s | **1.0x** | 5833.5 MB/s | 3781.2 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 5564.0 MB/s | 4803.3 MB/s | **0.9x** | 7085.7 MB/s | 4384.4 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 904.7 MB/s | 1640.3 MB/s | **1.8x** | 1266.2 MB/s | 5352.0 MB/s | **4.2x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 928.2 MB/s | 1619.8 MB/s | **1.7x** | 1544.4 MB/s | 5508.5 MB/s | **3.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5931.2 MB/s | 4979.4 MB/s | **0.8x** | 6057.3 MB/s | 9122.7 MB/s | **1.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5694.5 MB/s | 4997.1 MB/s | **0.9x** | 5408.3 MB/s | 9308.2 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 656.2 MB/s | 5024.7 MB/s | **7.7x** | 3472.8 MB/s | 8503.0 MB/s | **2.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 661.8 MB/s | 4864.6 MB/s | **7.4x** | 3490.0 MB/s | 9864.9 MB/s | **2.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1057.6 MB/s | 1886.8 MB/s | **1.8x** | 1753.1 MB/s | 10710.4 MB/s | **6.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1056.6 MB/s | 1883.7 MB/s | **1.8x** | 1809.6 MB/s | 9996.1 MB/s | **5.5x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 99.0 MB/s | 1285.0 MB/s | **13.0x** | 1740.6 MB/s | 11010.4 MB/s | **6.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 99.6 MB/s | 1288.1 MB/s | **12.9x** | 1851.3 MB/s | 11628.7 MB/s | **6.3x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 12001.7 MB/s | 25081.0 MB/s | **2.1x** | 5299.3 MB/s | 3586.0 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 9780.5 MB/s | 23039.2 MB/s | **2.4x** | 6197.8 MB/s | 4414.6 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2236.8 MB/s | 11183.3 MB/s | **5.0x** | 1902.7 MB/s | 3130.6 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2043.6 MB/s | 11285.8 MB/s | **5.5x** | 1976.3 MB/s | 3165.1 MB/s | **1.6x** | - |
