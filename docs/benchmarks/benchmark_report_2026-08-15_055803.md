# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 21:58:03 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 853.2 MB/s | 1547.6 MB/s | **1.8x** | 702.6 MB/s | 1420.8 MB/s | **2.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 817.3 MB/s | 1539.7 MB/s | **1.9x** | 512.3 MB/s | 1463.7 MB/s | **2.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 285.7 MB/s | 562.4 MB/s | **2.0x** | 592.8 MB/s | 1377.9 MB/s | **2.3x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 284.4 MB/s | 600.0 MB/s | **2.1x** | 498.7 MB/s | 1327.7 MB/s | **2.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 444.8 MB/s | 1184.6 MB/s | **2.7x** | 556.2 MB/s | 2229.7 MB/s | **4.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 400.7 MB/s | 891.8 MB/s | **2.2x** | 298.1 MB/s | 1991.5 MB/s | **6.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 315.9 MB/s | 1243.8 MB/s | **3.9x** | 587.7 MB/s | 2183.3 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 328.1 MB/s | 902.4 MB/s | **2.8x** | 297.1 MB/s | 1945.4 MB/s | **6.5x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 201.2 MB/s | 1051.4 MB/s | **5.2x** | 289.0 MB/s | 1038.8 MB/s | **3.6x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 289.1 MB/s | 1053.9 MB/s | **3.6x** | 281.6 MB/s | 1024.5 MB/s | **3.6x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1040.9 MB/s | 1876.8 MB/s | **1.8x** | 1341.8 MB/s | 4492.8 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 913.9 MB/s | 1823.7 MB/s | **2.0x** | 820.5 MB/s | 4689.3 MB/s | **5.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 288.1 MB/s | 557.2 MB/s | **1.9x** | 946.9 MB/s | 3742.7 MB/s | **4.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 283.4 MB/s | 558.6 MB/s | **2.0x** | 668.0 MB/s | 3675.5 MB/s | **5.5x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 649.1 MB/s | 1711.4 MB/s | **2.6x** | 980.4 MB/s | 5764.7 MB/s | **5.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 652.1 MB/s | 1626.1 MB/s | **2.5x** | 1048.4 MB/s | 4474.9 MB/s | **4.3x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 78.3 MB/s | 1218.2 MB/s | **15.6x** | 933.9 MB/s | 6392.4 MB/s | **6.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 77.9 MB/s | 1160.8 MB/s | **14.9x** | 990.6 MB/s | 4919.7 MB/s | **5.0x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1663.5 MB/s | 8819.4 MB/s | **5.3x** | 1620.2 MB/s | 5246.7 MB/s | **3.2x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1272.8 MB/s | 5893.6 MB/s | **4.6x** | 1530.3 MB/s | 5034.0 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 794.5 MB/s | 5081.0 MB/s | **6.4x** | 942.7 MB/s | 5353.3 MB/s | **5.7x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 759.1 MB/s | 4470.5 MB/s | **5.9x** | 934.4 MB/s | 5478.2 MB/s | **5.9x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 217.4 MB/s | 5093.8 MB/s | **23.4x** | 3883.9 MB/s | 6057.5 MB/s | **1.6x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 212.6 MB/s | 1233.0 MB/s | **5.8x** | 3225.6 MB/s | 7105.8 MB/s | **2.2x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 142.3 MB/s | 5199.1 MB/s | **36.5x** | 1644.3 MB/s | 6153.6 MB/s | **3.7x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 141.7 MB/s | 1312.0 MB/s | **9.3x** | 1503.7 MB/s | 7157.5 MB/s | **4.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 87.8 MB/s | 179.1 MB/s | **2.0x** | 3774.1 MB/s | 10100.6 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 80.4 MB/s | 172.1 MB/s | **2.1x** | 1771.0 MB/s | 2372.9 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 74.4 MB/s | 147.3 MB/s | **2.0x** | 3754.7 MB/s | 10881.9 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 69.4 MB/s | 140.7 MB/s | **2.0x** | 1698.0 MB/s | 2310.2 MB/s | **1.4x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 3747.5 MB/s | 5202.2 MB/s | **1.4x** | 5745.6 MB/s | 3770.4 MB/s | **0.7x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 5818.7 MB/s | 4919.8 MB/s | **0.8x** | 7073.3 MB/s | 4434.9 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 934.3 MB/s | 1671.7 MB/s | **1.8x** | 1593.4 MB/s | 5476.6 MB/s | **3.4x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 929.7 MB/s | 1706.3 MB/s | **1.8x** | 1611.7 MB/s | 5714.8 MB/s | **3.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 4680.8 MB/s | 4954.0 MB/s | **1.1x** | 5357.4 MB/s | 8591.7 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5125.9 MB/s | 4867.7 MB/s | **0.9x** | 4250.1 MB/s | 8780.5 MB/s | **2.1x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 599.1 MB/s | 4707.2 MB/s | **7.9x** | 3440.5 MB/s | 9298.7 MB/s | **2.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 638.9 MB/s | 4833.1 MB/s | **7.6x** | 3443.9 MB/s | 8910.2 MB/s | **2.6x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 981.2 MB/s | 1836.3 MB/s | **1.9x** | 1734.3 MB/s | 9914.4 MB/s | **5.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 979.9 MB/s | 1832.0 MB/s | **1.9x** | 1988.0 MB/s | 9842.2 MB/s | **5.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.5 MB/s | 1239.2 MB/s | **13.3x** | 1576.3 MB/s | 12276.6 MB/s | **7.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.3 MB/s | 1233.1 MB/s | **13.2x** | 1946.7 MB/s | 11496.6 MB/s | **5.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 11317.6 MB/s | 15919.5 MB/s | **1.4x** | 4857.0 MB/s | 4586.2 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 8826.2 MB/s | 20121.2 MB/s | **2.3x** | 5595.7 MB/s | 5453.9 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2429.0 MB/s | 9599.2 MB/s | **4.0x** | 1874.0 MB/s | 3028.0 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2110.4 MB/s | 9624.7 MB/s | **4.6x** | 1339.4 MB/s | 3076.8 MB/s | **2.3x** | - |
