# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 04:50:22 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 933.8 MB/s | 581.9 MB/s | **0.6x** | 733.8 MB/s | 584.9 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 881.2 MB/s | 567.5 MB/s | **0.6x** | 557.8 MB/s | 552.8 MB/s | **1.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 291.0 MB/s | 245.5 MB/s | **0.8x** | 615.1 MB/s | 745.6 MB/s | **1.2x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 290.1 MB/s | 241.1 MB/s | **0.8x** | 501.7 MB/s | 470.2 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 504.8 MB/s | 1301.7 MB/s | **2.6x** | 602.7 MB/s | 1985.1 MB/s | **3.3x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 480.0 MB/s | 954.3 MB/s | **2.0x** | 305.1 MB/s | 1865.7 MB/s | **6.1x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 413.4 MB/s | 1182.6 MB/s | **2.9x** | 600.8 MB/s | 1988.2 MB/s | **3.3x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 368.6 MB/s | 950.2 MB/s | **2.6x** | 308.3 MB/s | 1943.5 MB/s | **6.3x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 282.3 MB/s | 1072.6 MB/s | **3.8x** | 292.6 MB/s | 1107.8 MB/s | **3.8x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 292.7 MB/s | 1112.0 MB/s | **3.8x** | 295.2 MB/s | 1119.1 MB/s | **3.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1020.3 MB/s | 441.2 MB/s | **0.4x** | 1435.5 MB/s | 484.3 MB/s | **0.3x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 976.8 MB/s | 944.6 MB/s | **1.0x** | 878.1 MB/s | 848.3 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 299.7 MB/s | 295.6 MB/s | **1.0x** | 1025.5 MB/s | 1908.1 MB/s | **1.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 295.5 MB/s | 297.6 MB/s | **1.0x** | 694.6 MB/s | 680.5 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 677.7 MB/s | 1777.9 MB/s | **2.6x** | 1053.0 MB/s | 6693.1 MB/s | **6.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 671.8 MB/s | 1642.4 MB/s | **2.4x** | 1115.9 MB/s | 5016.0 MB/s | **4.5x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 80.0 MB/s | 1270.3 MB/s | **15.9x** | 995.0 MB/s | 6468.2 MB/s | **6.5x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 80.6 MB/s | 1190.2 MB/s | **14.8x** | 1060.7 MB/s | 5451.1 MB/s | **5.1x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1672.7 MB/s | 4025.7 MB/s | **2.4x** | 1651.7 MB/s | 4897.5 MB/s | **3.0x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1279.8 MB/s | 2734.6 MB/s | **2.1x** | 1351.3 MB/s | 3009.4 MB/s | **2.2x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 753.6 MB/s | 3511.9 MB/s | **4.7x** | 898.1 MB/s | 4884.1 MB/s | **5.4x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 818.3 MB/s | 4143.4 MB/s | **5.1x** | 932.3 MB/s | 5050.3 MB/s | **5.4x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.01 MB (100.0%) | 235.0 MB/s | 231.6 MB/s | **1.0x** | 4315.0 MB/s | 5060.1 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.01 MB (100.0%) | 233.7 MB/s | 230.0 MB/s | **1.0x** | 3367.2 MB/s | 3318.9 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 149.0 MB/s | 148.9 MB/s | **1.0x** | 1746.9 MB/s | 3939.5 MB/s | **2.3x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 145.2 MB/s | 147.5 MB/s | **1.0x** | 1545.4 MB/s | 1471.9 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 87.0 MB/s | 187.1 MB/s | **2.2x** | 4095.8 MB/s | 11270.0 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 85.5 MB/s | 175.9 MB/s | **2.1x** | 1943.5 MB/s | 2439.0 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 75.3 MB/s | 148.0 MB/s | **2.0x** | 4019.7 MB/s | 11849.5 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 71.7 MB/s | 140.7 MB/s | **2.0x** | 1881.6 MB/s | 2404.1 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 10.09 MB (10.1%) | 5761.2 MB/s | 8072.6 MB/s | **1.4x** | 5924.9 MB/s | 6414.2 MB/s | **1.1x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 10.09 MB (10.1%) | 6084.7 MB/s | 8169.1 MB/s | **1.3x** | 7362.0 MB/s | 6056.4 MB/s | **0.8x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 1030.5 MB/s | 1761.6 MB/s | **1.7x** | 1710.3 MB/s | 5559.1 MB/s | **3.3x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 929.5 MB/s | 1835.2 MB/s | **2.0x** | 1660.3 MB/s | 5336.2 MB/s | **3.2x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.11 MB (0.0%) | 5488.4 MB/s | 5104.7 MB/s | **0.9x** | 5819.6 MB/s | 2016.1 MB/s | **0.3x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.11 MB (0.0%) | 5534.0 MB/s | 5461.6 MB/s | **1.0x** | 5373.5 MB/s | 5334.5 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 691.4 MB/s | 692.3 MB/s | **1.0x** | 3660.5 MB/s | 2066.8 MB/s | **0.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 691.3 MB/s | 696.2 MB/s | **1.0x** | 3743.0 MB/s | 3574.9 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1050.8 MB/s | 1868.9 MB/s | **1.8x** | 1803.0 MB/s | 6973.1 MB/s | **3.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1043.6 MB/s | 1876.5 MB/s | **1.8x** | 2131.3 MB/s | 7649.3 MB/s | **3.6x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 97.3 MB/s | 1273.0 MB/s | **13.1x** | 1805.6 MB/s | 12325.8 MB/s | **6.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 96.9 MB/s | 1272.0 MB/s | **13.1x** | 2109.8 MB/s | 12428.8 MB/s | **5.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 16617.8 MB/s | 12674.6 MB/s | **0.8x** | 6263.6 MB/s | 6729.6 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10876.0 MB/s | 13076.1 MB/s | **1.2x** | 6233.3 MB/s | 7008.7 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2215.3 MB/s | 9482.9 MB/s | **4.3x** | 1985.1 MB/s | 3262.5 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2004.3 MB/s | 9565.4 MB/s | **4.8x** | 2013.2 MB/s | 3316.1 MB/s | **1.6x** | - |
