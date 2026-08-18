# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 21:07:06 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 818.9 MB/s | 745.9 MB/s | **0.9x** | 721.6 MB/s | 1363.0 MB/s | **1.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 829.7 MB/s | 930.0 MB/s | **1.1x** | 526.6 MB/s | 1500.6 MB/s | **2.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 295.5 MB/s | 408.5 MB/s | **1.4x** | 582.4 MB/s | 1342.4 MB/s | **2.3x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 258.6 MB/s | 432.5 MB/s | **1.7x** | 475.5 MB/s | 1400.3 MB/s | **2.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 458.7 MB/s | 1211.7 MB/s | **2.6x** | 509.1 MB/s | 2100.6 MB/s | **4.1x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 431.6 MB/s | 888.4 MB/s | **2.1x** | 305.6 MB/s | 1813.2 MB/s | **5.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 389.7 MB/s | 1248.2 MB/s | **3.2x** | 580.2 MB/s | 1956.2 MB/s | **3.4x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 365.1 MB/s | 945.8 MB/s | **2.6x** | 300.9 MB/s | 1923.3 MB/s | **6.4x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 298.7 MB/s | 1112.1 MB/s | **3.7x** | 295.8 MB/s | 1121.6 MB/s | **3.8x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 297.5 MB/s | 1090.2 MB/s | **3.7x** | 302.5 MB/s | 1106.2 MB/s | **3.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1113.4 MB/s | 2919.0 MB/s | **2.6x** | 1320.7 MB/s | 5793.3 MB/s | **4.4x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 963.1 MB/s | 2685.6 MB/s | **2.8x** | 876.6 MB/s | 5924.6 MB/s | **6.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 300.3 MB/s | 567.2 MB/s | **1.9x** | 1029.2 MB/s | 4107.9 MB/s | **4.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 297.1 MB/s | 578.8 MB/s | **1.9x** | 722.7 MB/s | 4261.6 MB/s | **5.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 680.2 MB/s | 1818.8 MB/s | **2.7x** | 1016.3 MB/s | 6923.6 MB/s | **6.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 667.9 MB/s | 1666.6 MB/s | **2.5x** | 1170.5 MB/s | 5170.0 MB/s | **4.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 77.8 MB/s | 1275.6 MB/s | **16.4x** | 971.2 MB/s | 7829.0 MB/s | **8.1x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 77.6 MB/s | 1198.4 MB/s | **15.5x** | 1044.9 MB/s | 5534.5 MB/s | **5.3x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1738.6 MB/s | 8595.2 MB/s | **4.9x** | 1795.5 MB/s | 5652.0 MB/s | **3.1x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1328.8 MB/s | 6162.2 MB/s | **4.6x** | 1632.5 MB/s | 5511.4 MB/s | **3.4x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 823.8 MB/s | 5338.3 MB/s | **6.5x** | 991.6 MB/s | 6153.0 MB/s | **6.2x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 809.7 MB/s | 5506.2 MB/s | **6.8x** | 1017.5 MB/s | 6156.3 MB/s | **6.1x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 238.2 MB/s | 5786.6 MB/s | **24.3x** | 3830.1 MB/s | 7157.0 MB/s | **1.9x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 236.2 MB/s | 1327.8 MB/s | **5.6x** | 3362.8 MB/s | 8211.1 MB/s | **2.4x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 150.2 MB/s | 5676.3 MB/s | **37.8x** | 1670.5 MB/s | 6899.1 MB/s | **4.1x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 150.6 MB/s | 1330.5 MB/s | **8.8x** | 1560.3 MB/s | 7909.1 MB/s | **5.1x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 88.1 MB/s | 184.2 MB/s | **2.1x** | 3599.0 MB/s | 11273.5 MB/s | **3.1x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 82.6 MB/s | 177.3 MB/s | **2.1x** | 1637.3 MB/s | 2022.7 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 75.3 MB/s | 149.2 MB/s | **2.0x** | 3772.8 MB/s | 10522.4 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 69.9 MB/s | 142.1 MB/s | **2.0x** | 1609.0 MB/s | 2370.5 MB/s | **1.5x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5106.1 MB/s | 4562.9 MB/s | **0.9x** | 5780.7 MB/s | 3636.5 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 4835.5 MB/s | 4462.8 MB/s | **0.9x** | 5638.5 MB/s | 3836.3 MB/s | **0.7x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 955.5 MB/s | 1647.4 MB/s | **1.7x** | 1102.1 MB/s | 4392.2 MB/s | **4.0x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 954.9 MB/s | 1614.7 MB/s | **1.7x** | 1673.2 MB/s | 5538.7 MB/s | **3.3x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5434.7 MB/s | 4741.9 MB/s | **0.9x** | 5854.2 MB/s | 8530.6 MB/s | **1.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5560.7 MB/s | 4634.9 MB/s | **0.8x** | 5460.6 MB/s | 9491.8 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 670.8 MB/s | 4690.2 MB/s | **7.0x** | 3534.8 MB/s | 9360.1 MB/s | **2.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 642.4 MB/s | 4591.4 MB/s | **7.1x** | 3194.9 MB/s | 8990.6 MB/s | **2.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1015.4 MB/s | 1852.9 MB/s | **1.8x** | 1611.4 MB/s | 10647.7 MB/s | **6.6x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1033.6 MB/s | 1854.3 MB/s | **1.8x** | 2052.8 MB/s | 10544.0 MB/s | **5.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.6 MB/s | 1257.6 MB/s | **13.3x** | 1648.7 MB/s | 12212.3 MB/s | **7.4x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 95.3 MB/s | 1250.7 MB/s | **13.1x** | 2033.7 MB/s | 12278.3 MB/s | **6.0x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 14725.9 MB/s | 20060.7 MB/s | **1.4x** | 5569.1 MB/s | 4586.7 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 11172.2 MB/s | 22261.6 MB/s | **2.0x** | 5319.6 MB/s | 4969.8 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2192.2 MB/s | 10808.7 MB/s | **4.9x** | 1860.1 MB/s | 3175.9 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2026.5 MB/s | 10720.7 MB/s | **5.3x** | 1825.0 MB/s | 3276.6 MB/s | **1.8x** | - |
