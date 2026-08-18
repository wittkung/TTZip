# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 21:29:25 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 912.5 MB/s | 2344.6 MB/s | **2.6x** | 737.9 MB/s | 1524.2 MB/s | **2.1x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 847.1 MB/s | 2572.9 MB/s | **3.0x** | 577.6 MB/s | 1490.4 MB/s | **2.6x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 293.3 MB/s | 533.1 MB/s | **1.8x** | 603.5 MB/s | 1349.1 MB/s | **2.2x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 275.9 MB/s | 568.6 MB/s | **2.1x** | 494.2 MB/s | 1295.6 MB/s | **2.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 486.7 MB/s | 1209.6 MB/s | **2.5x** | 572.5 MB/s | 2177.9 MB/s | **3.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 447.5 MB/s | 850.7 MB/s | **1.9x** | 289.2 MB/s | 1775.3 MB/s | **6.1x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 353.9 MB/s | 1117.4 MB/s | **3.2x** | 537.0 MB/s | 2119.2 MB/s | **3.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 359.6 MB/s | 837.3 MB/s | **2.3x** | 284.7 MB/s | 1692.3 MB/s | **5.9x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 252.2 MB/s | 967.4 MB/s | **3.8x** | 257.9 MB/s | 957.2 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 276.5 MB/s | 962.2 MB/s | **3.5x** | 291.5 MB/s | 1006.9 MB/s | **3.5x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 1031.4 MB/s | 3081.6 MB/s | **3.0x** | 1326.1 MB/s | 5820.4 MB/s | **4.4x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 937.4 MB/s | 3253.2 MB/s | **3.5x** | 811.0 MB/s | 6659.3 MB/s | **8.2x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 304.0 MB/s | 530.8 MB/s | **1.7x** | 992.9 MB/s | 4083.0 MB/s | **4.1x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 301.5 MB/s | 537.7 MB/s | **1.8x** | 661.1 MB/s | 3562.5 MB/s | **5.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 651.3 MB/s | 1774.6 MB/s | **2.7x** | 995.1 MB/s | 6646.3 MB/s | **6.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 639.3 MB/s | 1611.4 MB/s | **2.5x** | 1073.7 MB/s | 4980.8 MB/s | **4.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 77.9 MB/s | 1237.5 MB/s | **15.9x** | 994.3 MB/s | 7141.7 MB/s | **7.2x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 79.7 MB/s | 1193.6 MB/s | **15.0x** | 1074.8 MB/s | 5685.1 MB/s | **5.3x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1750.0 MB/s | 9216.4 MB/s | **5.3x** | 1814.0 MB/s | 5344.2 MB/s | **2.9x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1320.3 MB/s | 5982.3 MB/s | **4.5x** | 1636.5 MB/s | 5416.4 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 803.3 MB/s | 5568.2 MB/s | **6.9x** | 978.8 MB/s | 6111.9 MB/s | **6.2x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 799.1 MB/s | 5247.0 MB/s | **6.6x** | 968.3 MB/s | 6199.5 MB/s | **6.4x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 240.3 MB/s | 5840.3 MB/s | **24.3x** | 4402.1 MB/s | 7161.9 MB/s | **1.6x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 235.3 MB/s | 1402.0 MB/s | **6.0x** | 3198.2 MB/s | 7695.7 MB/s | **2.4x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 149.0 MB/s | 5889.9 MB/s | **39.5x** | 1670.3 MB/s | 6720.4 MB/s | **4.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 149.9 MB/s | 1452.0 MB/s | **9.7x** | 1554.2 MB/s | 7649.7 MB/s | **4.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 90.1 MB/s | 186.6 MB/s | **2.1x** | 3657.7 MB/s | 11062.8 MB/s | **3.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 83.0 MB/s | 174.8 MB/s | **2.1x** | 1871.0 MB/s | 2402.0 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 76.1 MB/s | 149.3 MB/s | **2.0x** | 3960.4 MB/s | 10367.3 MB/s | **2.6x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 71.4 MB/s | 142.6 MB/s | **2.0x** | 1892.6 MB/s | 2368.1 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4585.9 MB/s | 5371.4 MB/s | **1.2x** | 4918.2 MB/s | 3484.5 MB/s | **0.7x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 5738.8 MB/s | 5761.1 MB/s | **1.0x** | 7182.3 MB/s | 4557.2 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 1062.8 MB/s | 1822.7 MB/s | **1.7x** | 1600.5 MB/s | 5098.3 MB/s | **3.2x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 1001.1 MB/s | 1797.9 MB/s | **1.8x** | 1663.4 MB/s | 4655.3 MB/s | **2.8x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5602.6 MB/s | 5381.2 MB/s | **1.0x** | 5739.5 MB/s | 8426.5 MB/s | **1.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5931.3 MB/s | 5669.5 MB/s | **1.0x** | 5126.6 MB/s | 9399.9 MB/s | **1.8x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 673.3 MB/s | 5055.5 MB/s | **7.5x** | 3738.9 MB/s | 8662.9 MB/s | **2.3x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 678.4 MB/s | 5114.8 MB/s | **7.5x** | 3596.4 MB/s | 9852.6 MB/s | **2.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1021.4 MB/s | 1890.5 MB/s | **1.9x** | 1650.3 MB/s | 10498.9 MB/s | **6.4x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1047.0 MB/s | 1878.5 MB/s | **1.8x** | 2044.1 MB/s | 10791.3 MB/s | **5.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 98.4 MB/s | 1276.8 MB/s | **13.0x** | 1767.7 MB/s | 11812.0 MB/s | **6.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 98.8 MB/s | 1285.9 MB/s | **13.0x** | 2092.1 MB/s | 11981.3 MB/s | **5.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 12612.1 MB/s | 25248.1 MB/s | **2.0x** | 5707.3 MB/s | 4706.3 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10222.0 MB/s | 23042.4 MB/s | **2.3x** | 5878.7 MB/s | 4738.1 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2283.1 MB/s | 11250.7 MB/s | **4.9x** | 1966.0 MB/s | 3356.4 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2061.0 MB/s | 10993.8 MB/s | **5.3x** | 2034.5 MB/s | 3218.0 MB/s | **1.6x** | - |
