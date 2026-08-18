# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 21:44:25 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 852.5 MB/s | 2136.7 MB/s | **2.5x** | 711.9 MB/s | 1258.1 MB/s | **1.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 877.6 MB/s | 2211.5 MB/s | **2.5x** | 552.0 MB/s | 1447.2 MB/s | **2.6x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 293.3 MB/s | 571.6 MB/s | **1.9x** | 597.1 MB/s | 1399.2 MB/s | **2.3x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 290.5 MB/s | 609.3 MB/s | **2.1x** | 464.6 MB/s | 1298.2 MB/s | **2.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 450.0 MB/s | 1196.7 MB/s | **2.7x** | 595.0 MB/s | 2126.1 MB/s | **3.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 418.5 MB/s | 942.4 MB/s | **2.3x** | 310.6 MB/s | 1960.4 MB/s | **6.3x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 378.1 MB/s | 1266.3 MB/s | **3.3x** | 611.1 MB/s | 2131.4 MB/s | **3.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 356.1 MB/s | 941.2 MB/s | **2.6x** | 289.1 MB/s | 1885.2 MB/s | **6.5x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 273.9 MB/s | 1124.4 MB/s | **4.1x** | 290.8 MB/s | 1123.5 MB/s | **3.9x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 279.2 MB/s | 1045.3 MB/s | **3.7x** | 304.2 MB/s | 1086.5 MB/s | **3.6x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1077.3 MB/s | 2701.8 MB/s | **2.5x** | 1469.3 MB/s | 5404.4 MB/s | **3.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 967.3 MB/s | 2511.3 MB/s | **2.6x** | 864.9 MB/s | 5112.2 MB/s | **5.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 287.3 MB/s | 561.4 MB/s | **2.0x** | 1020.4 MB/s | 3958.2 MB/s | **3.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 287.9 MB/s | 576.1 MB/s | **2.0x** | 694.5 MB/s | 3958.2 MB/s | **5.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 680.4 MB/s | 1815.2 MB/s | **2.7x** | 1016.1 MB/s | 6222.2 MB/s | **6.1x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 639.4 MB/s | 1429.4 MB/s | **2.2x** | 1056.7 MB/s | 4587.7 MB/s | **4.3x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 78.2 MB/s | 1268.3 MB/s | **16.2x** | 984.4 MB/s | 6838.9 MB/s | **6.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 79.3 MB/s | 1213.6 MB/s | **15.3x** | 1071.8 MB/s | 5307.5 MB/s | **5.0x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1541.9 MB/s | 9593.1 MB/s | **6.2x** | 1854.8 MB/s | 5091.5 MB/s | **2.7x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1287.2 MB/s | 6337.7 MB/s | **4.9x** | 1641.2 MB/s | 5385.6 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 794.5 MB/s | 4855.6 MB/s | **6.1x** | 936.8 MB/s | 5635.9 MB/s | **6.0x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 772.9 MB/s | 3739.6 MB/s | **4.8x** | 901.9 MB/s | 5519.3 MB/s | **6.1x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 210.3 MB/s | 5263.9 MB/s | **25.0x** | 3995.9 MB/s | 6417.9 MB/s | **1.6x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 210.9 MB/s | 1358.4 MB/s | **6.4x** | 3324.3 MB/s | 6883.5 MB/s | **2.1x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 143.2 MB/s | 5377.3 MB/s | **37.5x** | 1664.1 MB/s | 6440.4 MB/s | **3.9x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 141.2 MB/s | 1392.2 MB/s | **9.9x** | 1463.2 MB/s | 7873.9 MB/s | **5.4x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 90.5 MB/s | 186.2 MB/s | **2.1x** | 3417.1 MB/s | 10523.4 MB/s | **3.1x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 84.2 MB/s | 178.6 MB/s | **2.1x** | 1864.0 MB/s | 2346.8 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 75.8 MB/s | 147.5 MB/s | **1.9x** | 3634.6 MB/s | 10563.6 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.9 MB/s | 136.9 MB/s | **1.9x** | 1763.0 MB/s | 2293.7 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5086.3 MB/s | 4712.1 MB/s | **0.9x** | 6292.9 MB/s | 3944.3 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 5814.2 MB/s | 5219.7 MB/s | **0.9x** | 6981.9 MB/s | 4108.6 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 914.4 MB/s | 1649.5 MB/s | **1.8x** | 1562.4 MB/s | 5715.3 MB/s | **3.7x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 903.2 MB/s | 1720.3 MB/s | **1.9x** | 1631.2 MB/s | 5889.0 MB/s | **3.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5663.0 MB/s | 4948.8 MB/s | **0.9x** | 5857.0 MB/s | 9597.0 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5513.9 MB/s | 4926.2 MB/s | **0.9x** | 5389.9 MB/s | 9568.4 MB/s | **1.8x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 655.3 MB/s | 4823.2 MB/s | **7.4x** | 3413.5 MB/s | 9590.2 MB/s | **2.8x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 641.1 MB/s | 4489.9 MB/s | **7.0x** | 3031.4 MB/s | 9098.9 MB/s | **3.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1014.2 MB/s | 1821.1 MB/s | **1.8x** | 1720.3 MB/s | 9820.1 MB/s | **5.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1023.0 MB/s | 1812.2 MB/s | **1.8x** | 1971.2 MB/s | 10070.7 MB/s | **5.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.8 MB/s | 1242.6 MB/s | **13.1x** | 1693.5 MB/s | 12060.1 MB/s | **7.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 95.2 MB/s | 1261.2 MB/s | **13.2x** | 2062.6 MB/s | 11631.3 MB/s | **5.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 16416.6 MB/s | 20815.3 MB/s | **1.3x** | 5767.1 MB/s | 4886.9 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10914.7 MB/s | 22944.9 MB/s | **2.1x** | 5920.0 MB/s | 5498.4 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2224.9 MB/s | 11566.6 MB/s | **5.2x** | 1979.8 MB/s | 3297.0 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2101.2 MB/s | 11408.7 MB/s | **5.4x** | 2004.7 MB/s | 3208.4 MB/s | **1.6x** | - |
