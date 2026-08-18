# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 18:58:31 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 540.8 MB/s | 528.6 MB/s | **1.0x** | 373.5 MB/s | 814.8 MB/s | **2.2x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 537.6 MB/s | 492.6 MB/s | **0.9x** | 327.4 MB/s | 470.1 MB/s | **1.4x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 207.6 MB/s | 225.0 MB/s | **1.1x** | 356.3 MB/s | 767.6 MB/s | **2.2x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 212.6 MB/s | 239.7 MB/s | **1.1x** | 270.2 MB/s | 481.4 MB/s | **1.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 291.4 MB/s | 639.0 MB/s | **2.2x** | 336.6 MB/s | 1670.8 MB/s | **5.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 287.8 MB/s | 391.8 MB/s | **1.4x** | 178.8 MB/s | 877.3 MB/s | **4.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 264.1 MB/s | 812.4 MB/s | **3.1x** | 363.4 MB/s | 1743.9 MB/s | **4.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 253.1 MB/s | 381.9 MB/s | **1.5x** | 213.4 MB/s | 1558.0 MB/s | **7.3x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 162.9 MB/s | 605.8 MB/s | **3.7x** | 160.4 MB/s | 592.1 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 180.9 MB/s | 632.6 MB/s | **3.5x** | 187.1 MB/s | 380.4 MB/s | **2.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 780.5 MB/s | 1521.3 MB/s | **1.9x** | 853.9 MB/s | 2983.0 MB/s | **3.5x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 650.0 MB/s | 1190.6 MB/s | **1.8x** | 522.6 MB/s | 946.4 MB/s | **1.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 210.7 MB/s | 318.2 MB/s | **1.5x** | 610.6 MB/s | 2373.4 MB/s | **3.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 203.1 MB/s | 337.4 MB/s | **1.7x** | 444.4 MB/s | 835.1 MB/s | **1.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 437.6 MB/s | 1146.3 MB/s | **2.6x** | 602.7 MB/s | 3044.8 MB/s | **5.1x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 382.7 MB/s | 947.7 MB/s | **2.5x** | 597.1 MB/s | 2466.9 MB/s | **4.1x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 55.1 MB/s | 752.2 MB/s | **13.6x** | 603.9 MB/s | 2878.3 MB/s | **4.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 58.1 MB/s | 798.7 MB/s | **13.7x** | 687.2 MB/s | 2722.1 MB/s | **4.0x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1039.4 MB/s | 4314.6 MB/s | **4.2x** | 1107.1 MB/s | 3450.7 MB/s | **3.1x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 882.9 MB/s | 2879.4 MB/s | **3.3x** | 995.6 MB/s | 3312.9 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 581.8 MB/s | 2891.1 MB/s | **5.0x** | 508.4 MB/s | 3241.4 MB/s | **6.4x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 545.1 MB/s | 2721.4 MB/s | **5.0x** | 496.7 MB/s | 2320.5 MB/s | **4.7x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 73.3 MB/s | 2360.5 MB/s | **32.2x** | 2504.4 MB/s | 3047.0 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 75.4 MB/s | 866.5 MB/s | **11.5x** | 1843.1 MB/s | 2824.0 MB/s | **1.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 79.7 MB/s | 2741.7 MB/s | **34.4x** | 1033.4 MB/s | 2246.5 MB/s | **2.2x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 73.6 MB/s | 702.6 MB/s | **9.6x** | 1011.8 MB/s | 3084.4 MB/s | **3.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 62.9 MB/s | 140.5 MB/s | **2.2x** | 2775.3 MB/s | 6053.3 MB/s | **2.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 62.8 MB/s | 123.7 MB/s | **2.0x** | 1359.6 MB/s | 1436.0 MB/s | **1.1x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 61.7 MB/s | 121.7 MB/s | **2.0x** | 2681.1 MB/s | 6176.3 MB/s | **2.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 56.3 MB/s | 117.9 MB/s | **2.1x** | 1298.4 MB/s | 1727.5 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 2916.0 MB/s | 3866.0 MB/s | **1.3x** | 3953.6 MB/s | 5142.8 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 3726.5 MB/s | 2683.3 MB/s | **0.7x** | 4247.0 MB/s | 3093.4 MB/s | **0.7x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 670.2 MB/s | 1123.2 MB/s | **1.7x** | 1256.2 MB/s | 3567.2 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 639.9 MB/s | 1203.7 MB/s | **1.9x** | 1032.9 MB/s | 4004.3 MB/s | **3.9x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.10 MB (0.0%) | 3814.5 MB/s | 12811.8 MB/s | **3.4x** | 3553.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.10 MB (0.0%) | 3874.3 MB/s | 12881.5 MB/s | **3.3x** | 3557.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 528.7 MB/s | 13751.8 MB/s | **26.0x** | 3077.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 519.7 MB/s | 13595.9 MB/s | **26.2x** | 2923.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 849.0 MB/s | 1585.0 MB/s | **1.9x** | 1498.4 MB/s | 5575.9 MB/s | **3.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 918.3 MB/s | 1594.2 MB/s | **1.7x** | 1788.1 MB/s | 7161.6 MB/s | **4.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 85.1 MB/s | 1099.1 MB/s | **12.9x** | 1366.6 MB/s | 7876.1 MB/s | **5.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 86.9 MB/s | 996.8 MB/s | **11.5x** | 1584.8 MB/s | 7232.0 MB/s | **4.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10922.4 MB/s | 16648.6 MB/s | **1.5x** | 4768.7 MB/s | 6530.2 MB/s | **1.4x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 8771.4 MB/s | 16448.1 MB/s | **1.9x** | 4853.3 MB/s | 6920.7 MB/s | **1.4x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 1813.1 MB/s | 5429.5 MB/s | **3.0x** | 1361.3 MB/s | 2164.9 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 1289.1 MB/s | 6697.0 MB/s | **5.2x** | 1008.7 MB/s | 2231.9 MB/s | **2.2x** | - |
