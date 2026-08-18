# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 17:38:50 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 906.0 MB/s | 763.7 MB/s | **0.8x** | 749.6 MB/s | 1312.2 MB/s | **1.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 835.2 MB/s | 576.9 MB/s | **0.7x** | 561.4 MB/s | 838.3 MB/s | **1.5x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 288.7 MB/s | 402.5 MB/s | **1.4x** | 620.7 MB/s | 1157.6 MB/s | **1.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 285.0 MB/s | 346.7 MB/s | **1.2x** | 499.8 MB/s | 752.6 MB/s | **1.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 461.0 MB/s | 1250.9 MB/s | **2.7x** | 587.8 MB/s | 1990.7 MB/s | **3.4x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 428.9 MB/s | 909.0 MB/s | **2.1x** | 306.4 MB/s | 1770.5 MB/s | **5.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 368.3 MB/s | 1249.5 MB/s | **3.4x** | 603.9 MB/s | 2059.1 MB/s | **3.4x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 352.8 MB/s | 911.1 MB/s | **2.6x** | 291.0 MB/s | 1844.9 MB/s | **6.3x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 285.9 MB/s | 1053.3 MB/s | **3.7x** | 278.9 MB/s | 569.1 MB/s | **2.0x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 288.0 MB/s | 979.6 MB/s | **3.4x** | 282.8 MB/s | 1008.5 MB/s | **3.6x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1043.9 MB/s | 1741.1 MB/s | **1.7x** | 1419.0 MB/s | 4580.9 MB/s | **3.2x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 937.7 MB/s | 873.1 MB/s | **0.9x** | 860.2 MB/s | 1341.4 MB/s | **1.6x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 288.1 MB/s | 514.3 MB/s | **1.8x** | 1009.3 MB/s | 3717.9 MB/s | **3.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 289.3 MB/s | 428.8 MB/s | **1.5x** | 682.7 MB/s | 1241.9 MB/s | **1.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 676.9 MB/s | 1751.0 MB/s | **2.6x** | 1013.3 MB/s | 6183.9 MB/s | **6.1x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 658.1 MB/s | 1570.9 MB/s | **2.4x** | 1061.6 MB/s | 4917.0 MB/s | **4.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 79.5 MB/s | 1265.0 MB/s | **15.9x** | 967.6 MB/s | 6651.4 MB/s | **6.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 79.6 MB/s | 1186.8 MB/s | **14.9x** | 1052.3 MB/s | 5072.8 MB/s | **4.8x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1598.7 MB/s | 5601.3 MB/s | **3.5x** | 1639.8 MB/s | 5323.5 MB/s | **3.2x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1269.3 MB/s | 3531.5 MB/s | **2.8x** | 1596.3 MB/s | 6145.5 MB/s | **3.8x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 695.5 MB/s | 4591.1 MB/s | **6.6x** | 916.2 MB/s | 5314.4 MB/s | **5.8x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 615.9 MB/s | 4358.4 MB/s | **7.1x** | 655.7 MB/s | 5355.7 MB/s | **8.2x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 223.2 MB/s | 4260.7 MB/s | **19.1x** | 4235.6 MB/s | 6379.4 MB/s | **1.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 213.1 MB/s | 1217.6 MB/s | **5.7x** | 3395.8 MB/s | 5512.9 MB/s | **1.6x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 144.5 MB/s | 5288.0 MB/s | **36.6x** | 1714.5 MB/s | 6692.8 MB/s | **3.9x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 144.6 MB/s | 1248.8 MB/s | **8.6x** | 1542.2 MB/s | 5559.7 MB/s | **3.6x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 88.0 MB/s | 181.4 MB/s | **2.1x** | 4039.4 MB/s | 11509.7 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 83.4 MB/s | 176.3 MB/s | **2.1x** | 1879.0 MB/s | 2391.7 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 73.6 MB/s | 148.0 MB/s | **2.0x** | 3845.6 MB/s | 11047.1 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 71.0 MB/s | 140.3 MB/s | **2.0x** | 1891.8 MB/s | 2393.1 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5938.7 MB/s | 3962.6 MB/s | **0.7x** | 6802.4 MB/s | 7264.7 MB/s | **1.1x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 12.63 MB (12.6%) | 6105.8 MB/s | 8921.8 MB/s | **1.5x** | 6967.5 MB/s | 8733.6 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 813.7 MB/s | 1764.3 MB/s | **2.2x** | 1662.3 MB/s | 5599.9 MB/s | **3.4x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 960.9 MB/s | 1781.6 MB/s | **1.9x** | 1370.3 MB/s | 5515.7 MB/s | **4.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5415.2 MB/s | 19474.3 MB/s | **3.6x** | 5751.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5403.0 MB/s | 16468.6 MB/s | **3.0x** | 5189.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 673.2 MB/s | 19608.4 MB/s | **29.1x** | 3887.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 677.8 MB/s | 15679.3 MB/s | **23.1x** | 3718.7 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1025.4 MB/s | 1843.8 MB/s | **1.8x** | 1741.9 MB/s | 7543.5 MB/s | **4.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1043.2 MB/s | 1850.7 MB/s | **1.8x** | 2102.1 MB/s | 8427.7 MB/s | **4.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 95.6 MB/s | 1255.3 MB/s | **13.1x** | 1731.2 MB/s | 8744.3 MB/s | **5.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 95.2 MB/s | 1261.3 MB/s | **13.3x** | 2098.8 MB/s | 11255.1 MB/s | **5.4x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 13752.8 MB/s | 13479.7 MB/s | **1.0x** | 6330.2 MB/s | 8550.2 MB/s | **1.4x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 11074.6 MB/s | 12698.5 MB/s | **1.1x** | 6429.0 MB/s | 8657.7 MB/s | **1.3x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2064.8 MB/s | 10236.7 MB/s | **5.0x** | 1370.7 MB/s | 3206.1 MB/s | **2.3x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 1991.3 MB/s | 10311.7 MB/s | **5.2x** | 2005.6 MB/s | 3266.8 MB/s | **1.6x** | - |
