# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 20:33:52 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 532.9 MB/s | 890.6 MB/s | **1.7x** | 540.9 MB/s | 875.7 MB/s | **1.6x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 789.9 MB/s | 845.7 MB/s | **1.1x** | 445.0 MB/s | 1355.6 MB/s | **3.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 289.8 MB/s | 409.5 MB/s | **1.4x** | 550.0 MB/s | 1071.7 MB/s | **1.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 288.2 MB/s | 407.5 MB/s | **1.4x** | 451.2 MB/s | 1005.5 MB/s | **2.2x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 458.6 MB/s | 1189.2 MB/s | **2.6x** | 529.4 MB/s | 1344.2 MB/s | **2.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 425.8 MB/s | 867.8 MB/s | **2.0x** | 283.1 MB/s | 1359.1 MB/s | **4.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 365.3 MB/s | 1212.0 MB/s | **3.3x** | 564.2 MB/s | 1509.4 MB/s | **2.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 339.1 MB/s | 855.0 MB/s | **2.5x** | 285.5 MB/s | 1773.9 MB/s | **6.2x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 202.0 MB/s | 819.1 MB/s | **4.1x** | 257.4 MB/s | 887.7 MB/s | **3.4x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 210.9 MB/s | 976.1 MB/s | **4.6x** | 257.4 MB/s | 979.9 MB/s | **3.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 966.9 MB/s | 1960.9 MB/s | **2.0x** | 1172.5 MB/s | 5398.3 MB/s | **4.6x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 684.1 MB/s | 2768.9 MB/s | **4.0x** | 764.1 MB/s | 5352.3 MB/s | **7.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 286.1 MB/s | 511.1 MB/s | **1.8x** | 925.9 MB/s | 3135.1 MB/s | **3.4x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 264.3 MB/s | 527.7 MB/s | **2.0x** | 548.2 MB/s | 3502.3 MB/s | **6.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 634.1 MB/s | 1682.5 MB/s | **2.7x** | 896.1 MB/s | 5249.5 MB/s | **5.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 615.7 MB/s | 1536.7 MB/s | **2.5x** | 952.5 MB/s | 4045.9 MB/s | **4.2x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 75.1 MB/s | 1113.8 MB/s | **14.8x** | 801.5 MB/s | 5631.0 MB/s | **7.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 72.2 MB/s | 1038.3 MB/s | **14.4x** | 901.0 MB/s | 4253.1 MB/s | **4.7x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 867.3 MB/s | 7800.1 MB/s | **9.0x** | 1411.9 MB/s | 5055.3 MB/s | **3.6x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1237.4 MB/s | 4915.9 MB/s | **4.0x** | 1238.3 MB/s | 4408.9 MB/s | **3.6x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 716.9 MB/s | 4503.0 MB/s | **6.3x** | 763.7 MB/s | 4650.5 MB/s | **6.1x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 763.3 MB/s | 4493.9 MB/s | **5.9x** | 845.5 MB/s | 4928.6 MB/s | **5.8x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 172.2 MB/s | 3055.9 MB/s | **17.7x** | 2465.2 MB/s | 6581.6 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 173.9 MB/s | 1262.5 MB/s | **7.3x** | 2185.5 MB/s | 7705.2 MB/s | **3.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 132.4 MB/s | 5248.1 MB/s | **39.6x** | 1482.0 MB/s | 6485.5 MB/s | **4.4x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 132.0 MB/s | 1296.1 MB/s | **9.8x** | 1475.3 MB/s | 6811.3 MB/s | **4.6x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 71.6 MB/s | 172.2 MB/s | **2.4x** | 2305.9 MB/s | 10832.9 MB/s | **4.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 79.4 MB/s | 158.9 MB/s | **2.0x** | 1425.9 MB/s | 2271.2 MB/s | **1.6x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 73.1 MB/s | 140.6 MB/s | **1.9x** | 2865.0 MB/s | 10926.4 MB/s | **3.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 69.4 MB/s | 139.1 MB/s | **2.0x** | 1608.1 MB/s | 2215.9 MB/s | **1.4x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5147.8 MB/s | 3927.9 MB/s | **0.8x** | 5878.0 MB/s | 3423.4 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 5136.0 MB/s | 4568.5 MB/s | **0.9x** | 6454.9 MB/s | 3841.9 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 894.1 MB/s | 1654.0 MB/s | **1.8x** | 1537.8 MB/s | 5020.7 MB/s | **3.3x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 802.4 MB/s | 1663.7 MB/s | **2.1x** | 1495.3 MB/s | 5123.4 MB/s | **3.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4735.8 MB/s | 4146.6 MB/s | **0.9x** | 4550.6 MB/s | 9009.6 MB/s | **2.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4967.5 MB/s | 4236.3 MB/s | **0.9x** | 4923.8 MB/s | 8647.9 MB/s | **1.8x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 650.2 MB/s | 4007.6 MB/s | **6.2x** | 3564.3 MB/s | 7994.7 MB/s | **2.2x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 621.9 MB/s | 4234.2 MB/s | **6.8x** | 3455.3 MB/s | 7945.4 MB/s | **2.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 984.7 MB/s | 1772.1 MB/s | **1.8x** | 1577.9 MB/s | 8823.7 MB/s | **5.6x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1010.0 MB/s | 1770.3 MB/s | **1.8x** | 1899.9 MB/s | 10105.4 MB/s | **5.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 90.4 MB/s | 1213.3 MB/s | **13.4x** | 1576.7 MB/s | 10025.6 MB/s | **6.4x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 90.1 MB/s | 1173.5 MB/s | **13.0x** | 1862.6 MB/s | 9785.3 MB/s | **5.3x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 13290.5 MB/s | 20533.2 MB/s | **1.5x** | 5505.6 MB/s | 4901.4 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 9162.0 MB/s | 19987.0 MB/s | **2.2x** | 4992.2 MB/s | 5077.1 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2038.2 MB/s | 7572.3 MB/s | **3.7x** | 1610.0 MB/s | 2687.9 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 1854.7 MB/s | 8181.8 MB/s | **4.4x** | 1602.5 MB/s | 2712.3 MB/s | **1.7x** | - |
