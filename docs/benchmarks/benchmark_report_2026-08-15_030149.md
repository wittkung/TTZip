# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 19:01:49 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 613.4 MB/s | 601.1 MB/s | **1.0x** | 476.3 MB/s | 895.4 MB/s | **1.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 642.2 MB/s | 575.3 MB/s | **0.9x** | 419.5 MB/s | 601.2 MB/s | **1.4x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 244.7 MB/s | 310.5 MB/s | **1.3x** | 460.5 MB/s | 890.7 MB/s | **1.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 255.2 MB/s | 321.5 MB/s | **1.3x** | 364.6 MB/s | 600.1 MB/s | **1.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 381.4 MB/s | 810.5 MB/s | **2.1x** | 448.7 MB/s | 1859.4 MB/s | **4.1x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 393.4 MB/s | 705.7 MB/s | **1.8x** | 243.1 MB/s | 1467.2 MB/s | **6.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 298.2 MB/s | 863.4 MB/s | **2.9x** | 394.7 MB/s | 1885.5 MB/s | **4.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 272.7 MB/s | 684.7 MB/s | **2.5x** | 139.5 MB/s | 1545.9 MB/s | **11.1x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 186.1 MB/s | 688.9 MB/s | **3.7x** | 189.6 MB/s | 733.5 MB/s | **3.9x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 264.2 MB/s | 882.8 MB/s | **3.3x** | 262.6 MB/s | 839.9 MB/s | **3.2x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 930.3 MB/s | 2245.8 MB/s | **2.4x** | 1205.7 MB/s | 4411.5 MB/s | **3.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 923.1 MB/s | 1538.1 MB/s | **1.7x** | 764.8 MB/s | 1327.3 MB/s | **1.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 290.3 MB/s | 510.9 MB/s | **1.8x** | 917.8 MB/s | 3755.8 MB/s | **4.1x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 287.5 MB/s | 526.1 MB/s | **1.8x** | 618.8 MB/s | 1178.8 MB/s | **1.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 635.9 MB/s | 1696.3 MB/s | **2.7x** | 897.8 MB/s | 5296.5 MB/s | **5.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 621.2 MB/s | 1434.9 MB/s | **2.3x** | 938.0 MB/s | 4631.3 MB/s | **4.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 77.0 MB/s | 1161.4 MB/s | **15.1x** | 853.6 MB/s | 6719.0 MB/s | **7.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 76.7 MB/s | 1159.4 MB/s | **15.1x** | 883.4 MB/s | 5443.4 MB/s | **6.2x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1531.9 MB/s | 6712.2 MB/s | **4.4x** | 1436.3 MB/s | 4810.3 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1186.7 MB/s | 3939.8 MB/s | **3.3x** | 1383.3 MB/s | 4595.1 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 708.1 MB/s | 4127.9 MB/s | **5.8x** | 876.2 MB/s | 5060.2 MB/s | **5.8x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 722.8 MB/s | 4040.4 MB/s | **5.6x** | 851.1 MB/s | 5371.4 MB/s | **6.3x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 133.8 MB/s | 4022.4 MB/s | **30.1x** | 2849.2 MB/s | 5705.7 MB/s | **2.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 125.8 MB/s | 977.3 MB/s | **7.8x** | 2111.2 MB/s | 3748.2 MB/s | **1.8x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 120.8 MB/s | 3425.5 MB/s | **28.4x** | 1552.8 MB/s | 4999.6 MB/s | **3.2x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 123.0 MB/s | 1217.0 MB/s | **9.9x** | 1359.7 MB/s | 4668.9 MB/s | **3.4x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 84.6 MB/s | 179.7 MB/s | **2.1x** | 3082.3 MB/s | 8669.6 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 81.5 MB/s | 168.3 MB/s | **2.1x** | 1674.5 MB/s | 2097.1 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.1 MB/s | 144.3 MB/s | **2.1x** | 3277.9 MB/s | 7491.6 MB/s | **2.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 63.4 MB/s | 138.0 MB/s | **2.2x** | 1754.8 MB/s | 1931.7 MB/s | **1.1x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5053.5 MB/s | 4491.4 MB/s | **0.9x** | 6515.2 MB/s | 4069.3 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 10.01 MB (10.0%) | 5786.5 MB/s | 13353.7 MB/s | **2.3x** | 6121.8 MB/s | 5332.7 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 885.7 MB/s | 1475.8 MB/s | **1.7x** | 1590.6 MB/s | 4972.9 MB/s | **3.1x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 859.7 MB/s | 1624.8 MB/s | **1.9x** | 1325.2 MB/s | 5004.9 MB/s | **3.8x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.10 MB (0.0%) | 4714.4 MB/s | 17222.4 MB/s | **3.7x** | 4503.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.10 MB (0.0%) | 4757.1 MB/s | 18649.8 MB/s | **3.9x** | 4649.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 666.8 MB/s | 17297.5 MB/s | **25.9x** | 3305.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 623.7 MB/s | 16242.8 MB/s | **26.0x** | 3121.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 939.4 MB/s | 1759.6 MB/s | **1.9x** | 1555.9 MB/s | 6049.8 MB/s | **3.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 706.8 MB/s | 1403.1 MB/s | **2.0x** | 1282.9 MB/s | 5113.1 MB/s | **4.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 86.1 MB/s | 935.6 MB/s | **10.9x** | 1533.9 MB/s | 8337.9 MB/s | **5.4x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 91.1 MB/s | 1189.3 MB/s | **13.0x** | 2055.6 MB/s | 11190.1 MB/s | **5.4x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 14772.0 MB/s | 17711.5 MB/s | **1.2x** | 5993.6 MB/s | 4896.6 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 9796.5 MB/s | 16006.2 MB/s | **1.6x** | 5212.6 MB/s | 5378.9 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 1996.2 MB/s | 7870.6 MB/s | **3.9x** | 1663.3 MB/s | 2688.1 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 1975.6 MB/s | 9276.4 MB/s | **4.7x** | 1479.7 MB/s | 2823.6 MB/s | **1.9x** | - |
