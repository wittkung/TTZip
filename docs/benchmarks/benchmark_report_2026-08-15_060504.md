# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 22:05:04 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 891.1 MB/s | 2215.8 MB/s | **2.5x** | 706.7 MB/s | 1498.1 MB/s | **2.1x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 869.8 MB/s | 2209.7 MB/s | **2.5x** | 534.9 MB/s | 1506.6 MB/s | **2.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 287.8 MB/s | 579.2 MB/s | **2.0x** | 595.0 MB/s | 1329.2 MB/s | **2.2x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 283.7 MB/s | 601.8 MB/s | **2.1x** | 489.7 MB/s | 1384.5 MB/s | **2.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 436.2 MB/s | 1206.0 MB/s | **2.8x** | 587.1 MB/s | 2306.9 MB/s | **3.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 413.1 MB/s | 909.8 MB/s | **2.2x** | 298.9 MB/s | 1852.3 MB/s | **6.2x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 354.9 MB/s | 1223.3 MB/s | **3.4x** | 587.9 MB/s | 2153.2 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 348.1 MB/s | 903.6 MB/s | **2.6x** | 300.3 MB/s | 2014.7 MB/s | **6.7x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 291.2 MB/s | 1005.6 MB/s | **3.5x** | 293.8 MB/s | 1085.7 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 199.8 MB/s | 1054.3 MB/s | **5.3x** | 285.2 MB/s | 1074.7 MB/s | **3.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 1043.8 MB/s | 3159.7 MB/s | **3.0x** | 1379.1 MB/s | 5618.3 MB/s | **4.1x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 937.2 MB/s | 3018.2 MB/s | **3.2x** | 840.9 MB/s | 5899.7 MB/s | **7.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 283.6 MB/s | 553.9 MB/s | **2.0x** | 991.9 MB/s | 3772.7 MB/s | **3.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 289.3 MB/s | 553.9 MB/s | **1.9x** | 646.7 MB/s | 3739.4 MB/s | **5.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 669.9 MB/s | 1765.6 MB/s | **2.6x** | 992.7 MB/s | 6091.0 MB/s | **6.1x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 652.4 MB/s | 1625.9 MB/s | **2.5x** | 1041.0 MB/s | 4728.2 MB/s | **4.5x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 80.2 MB/s | 1252.5 MB/s | **15.6x** | 956.5 MB/s | 6609.0 MB/s | **6.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 78.5 MB/s | 1189.0 MB/s | **15.1x** | 1015.9 MB/s | 5012.5 MB/s | **4.9x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1628.6 MB/s | 9273.5 MB/s | **5.7x** | 1587.9 MB/s | 5125.1 MB/s | **3.2x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1245.7 MB/s | 5677.4 MB/s | **4.6x** | 1531.8 MB/s | 5305.2 MB/s | **3.5x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 766.3 MB/s | 4977.4 MB/s | **6.5x** | 904.1 MB/s | 5513.6 MB/s | **6.1x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 782.9 MB/s | 5282.3 MB/s | **6.7x** | 918.7 MB/s | 5419.9 MB/s | **5.9x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 219.2 MB/s | 6112.4 MB/s | **27.9x** | 4294.0 MB/s | 7569.7 MB/s | **1.8x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 218.5 MB/s | 1436.6 MB/s | **6.6x** | 3378.9 MB/s | 8509.2 MB/s | **2.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 143.0 MB/s | 5902.3 MB/s | **41.3x** | 1619.7 MB/s | 7588.7 MB/s | **4.7x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 142.6 MB/s | 1426.9 MB/s | **10.0x** | 1524.9 MB/s | 8591.6 MB/s | **5.6x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 88.1 MB/s | 186.7 MB/s | **2.1x** | 3576.8 MB/s | 11022.7 MB/s | **3.1x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 84.5 MB/s | 178.8 MB/s | **2.1x** | 1837.2 MB/s | 2268.1 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 74.5 MB/s | 148.6 MB/s | **2.0x** | 3745.9 MB/s | 11204.6 MB/s | **3.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.8 MB/s | 141.4 MB/s | **2.0x** | 1854.3 MB/s | 2347.5 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5753.0 MB/s | 5150.5 MB/s | **0.9x** | 6753.1 MB/s | 3604.7 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 5321.8 MB/s | 4771.8 MB/s | **0.9x** | 6997.7 MB/s | 4258.0 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 1000.2 MB/s | 1778.0 MB/s | **1.8x** | 1603.9 MB/s | 5492.5 MB/s | **3.4x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 926.8 MB/s | 1772.1 MB/s | **1.9x** | 1572.0 MB/s | 5487.4 MB/s | **3.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5160.7 MB/s | 5106.3 MB/s | **1.0x** | 4939.9 MB/s | 8858.9 MB/s | **1.8x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 4902.0 MB/s | 5068.3 MB/s | **1.0x** | 5283.4 MB/s | 8964.6 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 654.9 MB/s | 4930.9 MB/s | **7.5x** | 3510.4 MB/s | 9137.7 MB/s | **2.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 672.5 MB/s | 4907.7 MB/s | **7.3x** | 3301.5 MB/s | 9157.1 MB/s | **2.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1014.2 MB/s | 1839.2 MB/s | **1.8x** | 1667.5 MB/s | 9913.1 MB/s | **5.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1020.3 MB/s | 1843.8 MB/s | **1.8x** | 1968.7 MB/s | 10324.3 MB/s | **5.2x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.9 MB/s | 1250.5 MB/s | **13.2x** | 1704.3 MB/s | 11323.2 MB/s | **6.6x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 96.3 MB/s | 1246.6 MB/s | **12.9x** | 2043.0 MB/s | 11544.5 MB/s | **5.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 13013.4 MB/s | 19111.4 MB/s | **1.5x** | 5458.8 MB/s | 4817.5 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 9857.9 MB/s | 22646.2 MB/s | **2.3x** | 5797.0 MB/s | 5444.6 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2267.3 MB/s | 10221.8 MB/s | **4.5x** | 1950.9 MB/s | 3246.3 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2063.4 MB/s | 10276.2 MB/s | **5.0x** | 1976.8 MB/s | 3219.2 MB/s | **1.6x** | - |
