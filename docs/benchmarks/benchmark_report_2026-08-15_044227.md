# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 20:42:27 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 786.1 MB/s | 825.4 MB/s | **1.1x** | 696.6 MB/s | 1334.1 MB/s | **1.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 774.2 MB/s | 883.0 MB/s | **1.1x** | 541.3 MB/s | 1589.3 MB/s | **2.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 298.7 MB/s | 402.1 MB/s | **1.3x** | 595.8 MB/s | 1422.1 MB/s | **2.4x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 292.9 MB/s | 420.6 MB/s | **1.4x** | 481.0 MB/s | 1367.0 MB/s | **2.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 471.5 MB/s | 1154.8 MB/s | **2.4x** | 564.6 MB/s | 2158.3 MB/s | **3.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 453.7 MB/s | 838.6 MB/s | **1.8x** | 292.6 MB/s | 1812.8 MB/s | **6.2x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 364.6 MB/s | 1194.8 MB/s | **3.3x** | 568.4 MB/s | 2211.6 MB/s | **3.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 368.9 MB/s | 897.9 MB/s | **2.4x** | 293.8 MB/s | 1781.4 MB/s | **6.1x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 237.8 MB/s | 933.1 MB/s | **3.9x** | 286.1 MB/s | 943.1 MB/s | **3.3x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 242.0 MB/s | 979.2 MB/s | **4.0x** | 280.1 MB/s | 1014.9 MB/s | **3.6x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 911.8 MB/s | 2316.6 MB/s | **2.5x** | 1198.9 MB/s | 5515.5 MB/s | **4.6x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 767.0 MB/s | 2577.5 MB/s | **3.4x** | 701.7 MB/s | 5704.4 MB/s | **8.1x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 288.9 MB/s | 467.2 MB/s | **1.6x** | 859.4 MB/s | 3222.1 MB/s | **3.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 282.1 MB/s | 464.8 MB/s | **1.6x** | 564.4 MB/s | 3207.1 MB/s | **5.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 600.4 MB/s | 1646.0 MB/s | **2.7x** | 803.4 MB/s | 5388.8 MB/s | **6.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 558.6 MB/s | 1460.8 MB/s | **2.6x** | 841.1 MB/s | 3888.2 MB/s | **4.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 79.3 MB/s | 1156.4 MB/s | **14.6x** | 765.9 MB/s | 5613.2 MB/s | **7.3x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 79.6 MB/s | 1113.7 MB/s | **14.0x** | 847.4 MB/s | 3920.6 MB/s | **4.6x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1376.6 MB/s | 5915.5 MB/s | **4.3x** | 1327.3 MB/s | 4469.6 MB/s | **3.4x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1044.9 MB/s | 4531.8 MB/s | **4.3x** | 1275.9 MB/s | 5008.8 MB/s | **3.9x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.7%) | 0.03 MB (0.4%) | 672.9 MB/s | 3611.6 MB/s | **5.4x** | 794.4 MB/s | 4756.6 MB/s | **6.0x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 668.6 MB/s | 3878.3 MB/s | **5.8x** | 812.9 MB/s | 5022.3 MB/s | **6.2x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 175.8 MB/s | 4694.7 MB/s | **26.7x** | 3706.6 MB/s | 5946.6 MB/s | **1.6x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 166.2 MB/s | 1333.8 MB/s | **8.0x** | 3290.0 MB/s | 6373.1 MB/s | **1.9x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 135.6 MB/s | 5188.5 MB/s | **38.3x** | 1613.2 MB/s | 5714.6 MB/s | **3.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 133.9 MB/s | 1283.5 MB/s | **9.6x** | 1502.8 MB/s | 7277.6 MB/s | **4.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 85.8 MB/s | 182.1 MB/s | **2.1x** | 3640.5 MB/s | 10757.2 MB/s | **3.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 76.2 MB/s | 170.3 MB/s | **2.2x** | 1604.8 MB/s | 2299.3 MB/s | **1.4x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.3 MB/s | 142.1 MB/s | **2.0x** | 3256.8 MB/s | 10750.5 MB/s | **3.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 68.8 MB/s | 138.9 MB/s | **2.0x** | 1671.3 MB/s | 2247.9 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5029.5 MB/s | 4756.9 MB/s | **0.9x** | 5848.2 MB/s | 3748.0 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 5278.2 MB/s | 4390.5 MB/s | **0.8x** | 6037.4 MB/s | 4060.6 MB/s | **0.7x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 882.2 MB/s | 1622.1 MB/s | **1.8x** | 1607.5 MB/s | 5372.2 MB/s | **3.3x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 848.1 MB/s | 1592.9 MB/s | **1.9x** | 1528.8 MB/s | 4749.2 MB/s | **3.1x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 4496.5 MB/s | 3812.9 MB/s | **0.8x** | 4763.9 MB/s | 8088.0 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 3950.3 MB/s | 4111.7 MB/s | **1.0x** | 3860.7 MB/s | 8264.5 MB/s | **2.1x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 592.6 MB/s | 3638.0 MB/s | **6.1x** | 3608.2 MB/s | 7514.6 MB/s | **2.1x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 634.4 MB/s | 4047.9 MB/s | **6.4x** | 3436.5 MB/s | 8545.4 MB/s | **2.5x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 975.2 MB/s | 1635.8 MB/s | **1.7x** | 1672.8 MB/s | 8126.3 MB/s | **4.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 993.6 MB/s | 1771.0 MB/s | **1.8x** | 1991.4 MB/s | 8354.1 MB/s | **4.2x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 92.6 MB/s | 1215.7 MB/s | **13.1x** | 1568.1 MB/s | 10405.8 MB/s | **6.6x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 92.6 MB/s | 1166.6 MB/s | **12.6x** | 2005.4 MB/s | 9699.4 MB/s | **4.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10016.1 MB/s | 14645.9 MB/s | **1.5x** | 4923.5 MB/s | 4277.5 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 8789.4 MB/s | 15806.6 MB/s | **1.8x** | 5732.0 MB/s | 4480.7 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2017.7 MB/s | 8580.7 MB/s | **4.3x** | 1737.0 MB/s | 2906.3 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 1944.4 MB/s | 8571.7 MB/s | **4.4x** | 1799.1 MB/s | 2705.5 MB/s | **1.5x** | - |
