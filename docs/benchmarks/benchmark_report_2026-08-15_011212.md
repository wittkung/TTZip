# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 17:12:12 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 878.7 MB/s | 569.5 MB/s | **0.6x** | 675.6 MB/s | 969.5 MB/s | **1.4x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 854.8 MB/s | 438.5 MB/s | **0.5x** | 514.8 MB/s | 700.0 MB/s | **1.4x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 290.2 MB/s | 382.5 MB/s | **1.3x** | 609.5 MB/s | 1172.2 MB/s | **1.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 284.1 MB/s | 347.6 MB/s | **1.2x** | 452.6 MB/s | 667.0 MB/s | **1.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 458.8 MB/s | 1213.2 MB/s | **2.6x** | 542.7 MB/s | 1783.5 MB/s | **3.3x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 432.3 MB/s | 879.4 MB/s | **2.0x** | 290.5 MB/s | 1530.8 MB/s | **5.3x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 379.0 MB/s | 1175.4 MB/s | **3.1x** | 569.0 MB/s | 1743.3 MB/s | **3.1x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 354.9 MB/s | 921.8 MB/s | **2.6x** | 288.1 MB/s | 1523.4 MB/s | **5.3x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 189.4 MB/s | 1055.7 MB/s | **5.6x** | 277.6 MB/s | 837.1 MB/s | **3.0x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 277.4 MB/s | 1063.2 MB/s | **3.8x** | 275.8 MB/s | 822.8 MB/s | **3.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1042.1 MB/s | 880.4 MB/s | **0.8x** | 1407.0 MB/s | 1239.1 MB/s | **0.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 944.5 MB/s | 591.8 MB/s | **0.6x** | 840.9 MB/s | 1158.5 MB/s | **1.4x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 296.4 MB/s | 552.7 MB/s | **1.9x** | 982.5 MB/s | 3691.2 MB/s | **3.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 276.9 MB/s | 428.9 MB/s | **1.5x** | 634.8 MB/s | 1124.8 MB/s | **1.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 613.2 MB/s | 1636.3 MB/s | **2.7x** | 953.3 MB/s | 5396.5 MB/s | **5.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 643.3 MB/s | 1574.2 MB/s | **2.4x** | 1026.4 MB/s | 4913.8 MB/s | **4.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 76.1 MB/s | 1231.2 MB/s | **16.2x** | 904.7 MB/s | 6896.5 MB/s | **7.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 75.8 MB/s | 1117.2 MB/s | **14.7x** | 1010.5 MB/s | 4761.0 MB/s | **4.7x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1669.7 MB/s | 4774.0 MB/s | **2.9x** | 1664.3 MB/s | 6231.5 MB/s | **3.7x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1270.1 MB/s | 3330.3 MB/s | **2.6x** | 1574.0 MB/s | 5667.3 MB/s | **3.6x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 759.3 MB/s | 4956.8 MB/s | **6.5x** | 943.8 MB/s | 5556.7 MB/s | **5.9x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 774.2 MB/s | 4889.1 MB/s | **6.3x** | 935.7 MB/s | 5716.1 MB/s | **6.1x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 214.7 MB/s | 4499.9 MB/s | **21.0x** | 2107.9 MB/s | 5989.2 MB/s | **2.8x** | 2_SolidBuf_IO_and_CRC32 (91.5%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 209.4 MB/s | 4341.0 MB/s | **20.7x** | 2625.5 MB/s | 6066.5 MB/s | **2.3x** | 2_SolidBuf_IO_and_CRC32 (91.4%) |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 141.8 MB/s | 4164.1 MB/s | **29.4x** | 1670.0 MB/s | 6885.1 MB/s | **4.1x** | 2_SolidBuf_IO_and_CRC32 (91.3%) |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 142.0 MB/s | 4159.0 MB/s | **29.3x** | 1418.8 MB/s | 7459.6 MB/s | **5.3x** | 2_SolidBuf_IO_and_CRC32 (91.1%) |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 90.3 MB/s | 184.9 MB/s | **2.0x** | 4026.1 MB/s | 11029.6 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 83.0 MB/s | 173.9 MB/s | **2.1x** | 1714.0 MB/s | 2300.0 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 73.6 MB/s | 147.5 MB/s | **2.0x** | 3669.2 MB/s | 10766.0 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 69.3 MB/s | 138.5 MB/s | **2.0x** | 1741.6 MB/s | 2290.3 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5055.2 MB/s | 3555.8 MB/s | **0.7x** | 7004.3 MB/s | 6119.7 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 12.63 MB (12.6%) | 5656.1 MB/s | 8775.0 MB/s | **1.6x** | 5881.9 MB/s | 7754.9 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 972.0 MB/s | 1735.2 MB/s | **1.8x** | 1579.4 MB/s | 5305.2 MB/s | **3.4x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 952.9 MB/s | 1745.0 MB/s | **1.8x** | 1612.2 MB/s | 5806.7 MB/s | **3.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5499.5 MB/s | 20114.2 MB/s | **3.7x** | 5874.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5374.8 MB/s | 15901.6 MB/s | **3.0x** | 4553.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 681.2 MB/s | 18496.3 MB/s | **27.2x** | 3668.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 688.9 MB/s | 16049.2 MB/s | **23.3x** | 3477.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1006.1 MB/s | 1835.0 MB/s | **1.8x** | 1760.5 MB/s | 7159.2 MB/s | **4.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1011.0 MB/s | 1848.8 MB/s | **1.8x** | 2053.2 MB/s | 7498.1 MB/s | **3.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 95.2 MB/s | 1233.1 MB/s | **13.0x** | 1734.1 MB/s | 11538.2 MB/s | **6.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.8 MB/s | 1224.8 MB/s | **12.9x** | 1966.2 MB/s | 11998.7 MB/s | **6.1x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 14263.7 MB/s | 13773.6 MB/s | **1.0x** | 6066.2 MB/s | 7850.6 MB/s | **1.3x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10914.9 MB/s | 13162.7 MB/s | **1.2x** | 6267.5 MB/s | 8493.2 MB/s | **1.4x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2036.3 MB/s | 10089.3 MB/s | **5.0x** | 1957.0 MB/s | 3112.3 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2040.3 MB/s | 10536.6 MB/s | **5.2x** | 2022.7 MB/s | 3303.6 MB/s | **1.6x** | - |
