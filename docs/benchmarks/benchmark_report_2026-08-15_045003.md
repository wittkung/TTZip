# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 20:50:03 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 895.4 MB/s | 919.3 MB/s | **1.0x** | 714.7 MB/s | 1379.5 MB/s | **1.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 874.2 MB/s | 946.1 MB/s | **1.1x** | 567.1 MB/s | 1457.7 MB/s | **2.6x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 293.2 MB/s | 401.4 MB/s | **1.4x** | 605.1 MB/s | 1261.8 MB/s | **2.1x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 293.4 MB/s | 440.4 MB/s | **1.5x** | 503.8 MB/s | 1392.6 MB/s | **2.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 520.9 MB/s | 1246.3 MB/s | **2.4x** | 605.5 MB/s | 2297.5 MB/s | **3.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 476.9 MB/s | 919.5 MB/s | **1.9x** | 299.5 MB/s | 1892.5 MB/s | **6.3x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 411.9 MB/s | 1286.2 MB/s | **3.1x** | 595.8 MB/s | 2109.5 MB/s | **3.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 382.9 MB/s | 919.0 MB/s | **2.4x** | 301.2 MB/s | 1884.1 MB/s | **6.3x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 277.0 MB/s | 978.5 MB/s | **3.5x** | 280.2 MB/s | 1079.4 MB/s | **3.9x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 284.5 MB/s | 1025.0 MB/s | **3.6x** | 276.6 MB/s | 1057.0 MB/s | **3.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1102.1 MB/s | 2672.5 MB/s | **2.4x** | 1430.1 MB/s | 5481.1 MB/s | **3.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 970.0 MB/s | 2983.7 MB/s | **3.1x** | 881.5 MB/s | 5571.7 MB/s | **6.3x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 306.5 MB/s | 555.2 MB/s | **1.8x** | 1013.2 MB/s | 4070.4 MB/s | **4.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 295.7 MB/s | 553.6 MB/s | **1.9x** | 695.6 MB/s | 3885.5 MB/s | **5.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 673.3 MB/s | 1778.2 MB/s | **2.6x** | 1015.8 MB/s | 6524.7 MB/s | **6.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 656.6 MB/s | 1626.8 MB/s | **2.5x** | 1082.9 MB/s | 5051.4 MB/s | **4.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 79.2 MB/s | 1265.0 MB/s | **16.0x** | 985.1 MB/s | 7823.8 MB/s | **7.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 78.6 MB/s | 1191.2 MB/s | **15.1x** | 1043.1 MB/s | 5365.2 MB/s | **5.1x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1700.0 MB/s | 9055.6 MB/s | **5.3x** | 1710.1 MB/s | 5012.5 MB/s | **2.9x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1284.1 MB/s | 6004.2 MB/s | **4.7x** | 1615.6 MB/s | 5315.1 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 797.0 MB/s | 4987.0 MB/s | **6.3x** | 946.5 MB/s | 5889.3 MB/s | **6.2x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 786.1 MB/s | 3133.6 MB/s | **4.0x** | 942.5 MB/s | 5067.4 MB/s | **5.4x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 229.4 MB/s | 5449.6 MB/s | **23.8x** | 4358.0 MB/s | 6818.0 MB/s | **1.6x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 224.8 MB/s | 1249.6 MB/s | **5.6x** | 3425.9 MB/s | 7579.0 MB/s | **2.2x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 147.2 MB/s | 5490.5 MB/s | **37.3x** | 1669.3 MB/s | 6724.7 MB/s | **4.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 147.1 MB/s | 1385.5 MB/s | **9.4x** | 1578.8 MB/s | 7919.0 MB/s | **5.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 90.4 MB/s | 184.9 MB/s | **2.0x** | 3944.1 MB/s | 11609.1 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 81.9 MB/s | 177.0 MB/s | **2.2x** | 1800.7 MB/s | 2406.7 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 75.7 MB/s | 149.0 MB/s | **2.0x** | 3860.9 MB/s | 11980.5 MB/s | **3.1x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 71.0 MB/s | 141.9 MB/s | **2.0x** | 1878.4 MB/s | 2392.9 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4891.1 MB/s | 5225.4 MB/s | **1.1x** | 5388.5 MB/s | 4122.2 MB/s | **0.8x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 5742.7 MB/s | 4622.5 MB/s | **0.8x** | 5603.3 MB/s | 4153.5 MB/s | **0.7x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 1015.6 MB/s | 1771.7 MB/s | **1.7x** | 1623.1 MB/s | 5014.4 MB/s | **3.1x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 990.0 MB/s | 1840.2 MB/s | **1.9x** | 1616.8 MB/s | 5761.3 MB/s | **3.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5674.1 MB/s | 4638.3 MB/s | **0.8x** | 5675.3 MB/s | 8994.9 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5509.9 MB/s | 4659.2 MB/s | **0.8x** | 4338.4 MB/s | 9423.1 MB/s | **2.2x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 677.3 MB/s | 4223.7 MB/s | **6.2x** | 3903.1 MB/s | 9536.5 MB/s | **2.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 686.6 MB/s | 4647.0 MB/s | **6.8x** | 3280.0 MB/s | 9871.0 MB/s | **3.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1044.7 MB/s | 1864.9 MB/s | **1.8x** | 1728.9 MB/s | 10641.2 MB/s | **6.2x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1032.3 MB/s | 1846.4 MB/s | **1.8x** | 2077.6 MB/s | 10647.8 MB/s | **5.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 96.0 MB/s | 1262.3 MB/s | **13.1x** | 1730.6 MB/s | 12302.3 MB/s | **7.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 95.6 MB/s | 1251.9 MB/s | **13.1x** | 2077.2 MB/s | 12291.0 MB/s | **5.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 13765.3 MB/s | 18835.4 MB/s | **1.4x** | 5586.5 MB/s | 3917.0 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 11124.9 MB/s | 20665.9 MB/s | **1.9x** | 6869.8 MB/s | 4632.2 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2076.2 MB/s | 10741.0 MB/s | **5.2x** | 1888.2 MB/s | 3053.9 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2071.4 MB/s | 10851.7 MB/s | **5.2x** | 1980.9 MB/s | 3218.0 MB/s | **1.6x** | - |
