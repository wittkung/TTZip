# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 21:32:29 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 801.4 MB/s | 2432.2 MB/s | **3.0x** | 635.5 MB/s | 1476.5 MB/s | **2.3x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 826.0 MB/s | 2320.4 MB/s | **2.8x** | 558.1 MB/s | 1582.4 MB/s | **2.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 288.9 MB/s | 542.2 MB/s | **1.9x** | 602.4 MB/s | 1390.4 MB/s | **2.3x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 289.2 MB/s | 577.0 MB/s | **2.0x** | 490.2 MB/s | 1401.1 MB/s | **2.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 427.0 MB/s | 1258.2 MB/s | **2.9x** | 588.8 MB/s | 2191.9 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 403.9 MB/s | 864.2 MB/s | **2.1x** | 305.9 MB/s | 1888.5 MB/s | **6.2x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 336.0 MB/s | 1309.4 MB/s | **3.9x** | 583.6 MB/s | 2168.3 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 341.8 MB/s | 899.3 MB/s | **2.6x** | 298.6 MB/s | 1915.0 MB/s | **6.4x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 177.1 MB/s | 1041.9 MB/s | **5.9x** | 280.8 MB/s | 1084.0 MB/s | **3.9x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 287.9 MB/s | 1080.3 MB/s | **3.8x** | 289.2 MB/s | 1115.9 MB/s | **3.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 1072.6 MB/s | 2571.0 MB/s | **2.4x** | 1373.8 MB/s | 5692.0 MB/s | **4.1x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 889.5 MB/s | 3021.8 MB/s | **3.4x** | 820.2 MB/s | 5344.1 MB/s | **6.5x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 290.1 MB/s | 556.0 MB/s | **1.9x** | 972.6 MB/s | 3390.5 MB/s | **3.5x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 284.0 MB/s | 548.4 MB/s | **1.9x** | 659.4 MB/s | 3715.3 MB/s | **5.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 665.4 MB/s | 1767.7 MB/s | **2.7x** | 973.5 MB/s | 5940.2 MB/s | **6.1x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 648.3 MB/s | 1614.0 MB/s | **2.5x** | 1009.0 MB/s | 4668.8 MB/s | **4.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 80.1 MB/s | 1238.8 MB/s | **15.5x** | 882.4 MB/s | 6465.0 MB/s | **7.3x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 78.2 MB/s | 1152.7 MB/s | **14.7x** | 1032.7 MB/s | 4865.6 MB/s | **4.7x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1522.5 MB/s | 8774.6 MB/s | **5.8x** | 1581.0 MB/s | 5107.7 MB/s | **3.2x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1217.8 MB/s | 6242.5 MB/s | **5.1x** | 1594.5 MB/s | 5283.7 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 735.9 MB/s | 4956.1 MB/s | **6.7x** | 919.5 MB/s | 5465.2 MB/s | **5.9x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 765.6 MB/s | 4590.7 MB/s | **6.0x** | 853.9 MB/s | 5477.0 MB/s | **6.4x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 169.1 MB/s | 4470.2 MB/s | **26.4x** | 3903.0 MB/s | 6080.8 MB/s | **1.6x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 179.6 MB/s | 1297.8 MB/s | **7.2x** | 3171.2 MB/s | 7357.4 MB/s | **2.3x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 136.8 MB/s | 5394.4 MB/s | **39.4x** | 1648.7 MB/s | 6096.8 MB/s | **3.7x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 127.8 MB/s | 1386.4 MB/s | **10.8x** | 1536.7 MB/s | 7473.8 MB/s | **4.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 90.2 MB/s | 185.8 MB/s | **2.1x** | 3550.0 MB/s | 10155.8 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 82.8 MB/s | 174.4 MB/s | **2.1x** | 1813.0 MB/s | 2365.3 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 71.9 MB/s | 146.3 MB/s | **2.0x** | 3436.7 MB/s | 10662.6 MB/s | **3.1x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.0 MB/s | 124.9 MB/s | **1.8x** | 1846.6 MB/s | 2283.6 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4858.8 MB/s | 5496.5 MB/s | **1.1x** | 5486.9 MB/s | 3654.1 MB/s | **0.7x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 6075.7 MB/s | 5674.1 MB/s | **0.9x** | 6820.8 MB/s | 4455.4 MB/s | **0.7x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 997.2 MB/s | 1784.9 MB/s | **1.8x** | 1637.3 MB/s | 5851.9 MB/s | **3.6x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 985.0 MB/s | 1833.2 MB/s | **1.9x** | 1691.0 MB/s | 5840.7 MB/s | **3.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5512.7 MB/s | 5217.6 MB/s | **0.9x** | 5496.5 MB/s | 9403.5 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5638.8 MB/s | 5156.6 MB/s | **0.9x** | 5249.0 MB/s | 9545.4 MB/s | **1.8x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 671.2 MB/s | 4990.4 MB/s | **7.4x** | 3888.8 MB/s | 9815.7 MB/s | **2.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 667.4 MB/s | 4957.1 MB/s | **7.4x** | 3519.5 MB/s | 9357.0 MB/s | **2.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1039.7 MB/s | 1880.0 MB/s | **1.8x** | 1535.5 MB/s | 10739.4 MB/s | **7.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 992.2 MB/s | 1822.9 MB/s | **1.8x** | 1850.3 MB/s | 9820.2 MB/s | **5.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.0 MB/s | 1254.9 MB/s | **13.4x** | 1674.3 MB/s | 11977.3 MB/s | **7.2x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.7 MB/s | 1259.5 MB/s | **13.4x** | 1855.9 MB/s | 11325.2 MB/s | **6.1x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 13464.2 MB/s | 24209.6 MB/s | **1.8x** | 5449.2 MB/s | 4570.1 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 9526.0 MB/s | 20303.2 MB/s | **2.1x** | 5782.3 MB/s | 5452.8 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2377.7 MB/s | 10252.5 MB/s | **4.3x** | 1867.4 MB/s | 3022.8 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2126.7 MB/s | 10027.6 MB/s | **4.7x** | 1876.4 MB/s | 3119.4 MB/s | **1.7x** | - |
