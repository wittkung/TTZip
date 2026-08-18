# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 20:03:46 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 800.2 MB/s | 817.0 MB/s | **1.0x** | 363.9 MB/s | 473.9 MB/s | **1.3x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 829.1 MB/s | 757.7 MB/s | **0.9x** | 455.1 MB/s | 969.7 MB/s | **2.1x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 295.8 MB/s | 389.9 MB/s | **1.3x** | 586.5 MB/s | 925.3 MB/s | **1.6x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 295.3 MB/s | 427.1 MB/s | **1.4x** | 288.1 MB/s | 1001.9 MB/s | **3.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 485.1 MB/s | 1236.2 MB/s | **2.5x** | 333.9 MB/s | 766.2 MB/s | **2.3x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 461.4 MB/s | 874.6 MB/s | **1.9x** | 211.7 MB/s | 800.2 MB/s | **3.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 335.9 MB/s | 1198.3 MB/s | **3.6x** | 399.0 MB/s | 589.3 MB/s | **1.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 368.1 MB/s | 874.1 MB/s | **2.4x** | 264.3 MB/s | 1062.9 MB/s | **4.0x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 235.8 MB/s | 944.3 MB/s | **4.0x** | 222.5 MB/s | 561.3 MB/s | **2.5x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 256.6 MB/s | 977.6 MB/s | **3.8x** | 234.3 MB/s | 301.2 MB/s | **1.3x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1064.0 MB/s | 1216.4 MB/s | **1.1x** | 1371.7 MB/s | 3770.3 MB/s | **2.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 892.4 MB/s | 1730.7 MB/s | **1.9x** | 805.0 MB/s | 3671.3 MB/s | **4.6x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 286.7 MB/s | 520.4 MB/s | **1.8x** | 885.8 MB/s | 2589.5 MB/s | **2.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 288.0 MB/s | 526.1 MB/s | **1.8x** | 636.6 MB/s | 2800.1 MB/s | **4.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 606.4 MB/s | 1606.1 MB/s | **2.6x** | 823.1 MB/s | 5250.0 MB/s | **6.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 595.7 MB/s | 1501.0 MB/s | **2.5x** | 900.0 MB/s | 4511.8 MB/s | **5.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 75.6 MB/s | 1157.0 MB/s | **15.3x** | 906.0 MB/s | 5746.7 MB/s | **6.3x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 76.0 MB/s | 1131.5 MB/s | **14.9x** | 855.4 MB/s | 4228.9 MB/s | **4.9x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 935.8 MB/s | 6272.9 MB/s | **6.7x** | 1490.1 MB/s | 4319.2 MB/s | **2.9x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1253.3 MB/s | 3655.2 MB/s | **2.9x** | 1433.3 MB/s | 4714.8 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 721.7 MB/s | 4996.9 MB/s | **6.9x** | 813.3 MB/s | 3592.0 MB/s | **4.4x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 748.7 MB/s | 5122.3 MB/s | **6.8x** | 894.0 MB/s | 2315.6 MB/s | **2.6x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 194.1 MB/s | 4517.2 MB/s | **23.3x** | 3498.7 MB/s | 1249.2 MB/s | **0.4x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 197.3 MB/s | 1231.1 MB/s | **6.2x** | 2051.7 MB/s | 2092.3 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 122.8 MB/s | 4630.6 MB/s | **37.7x** | 1242.1 MB/s | 1811.7 MB/s | **1.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 128.4 MB/s | 1176.2 MB/s | **9.2x** | 1463.7 MB/s | 1610.5 MB/s | **1.1x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 83.1 MB/s | 163.6 MB/s | **2.0x** | 2865.0 MB/s | 10920.9 MB/s | **3.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 75.6 MB/s | 169.3 MB/s | **2.2x** | 1747.6 MB/s | 2310.5 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 72.0 MB/s | 141.6 MB/s | **2.0x** | 2640.1 MB/s | 11213.5 MB/s | **4.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 68.9 MB/s | 137.6 MB/s | **2.0x** | 1698.7 MB/s | 2194.6 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 2935.3 MB/s | 3767.9 MB/s | **1.3x** | 3704.6 MB/s | 2129.5 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 10.01 MB (10.0%) | 5638.2 MB/s | 14411.3 MB/s | **2.6x** | 4222.8 MB/s | 2448.4 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 995.1 MB/s | 1721.3 MB/s | **1.7x** | 1542.1 MB/s | 3322.0 MB/s | **2.2x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 938.3 MB/s | 1743.8 MB/s | **1.9x** | 1628.5 MB/s | 5778.4 MB/s | **3.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5513.0 MB/s | 2684.2 MB/s | **0.5x** | 3909.0 MB/s | 2026.3 MB/s | **0.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5303.3 MB/s | 4607.9 MB/s | **0.9x** | 3375.4 MB/s | 2333.0 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 651.7 MB/s | 4463.9 MB/s | **6.8x** | 2642.4 MB/s | 3472.8 MB/s | **1.3x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 680.7 MB/s | 4123.3 MB/s | **6.1x** | 2853.2 MB/s | 3811.5 MB/s | **1.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1033.4 MB/s | 1782.8 MB/s | **1.7x** | 1671.7 MB/s | 10023.3 MB/s | **6.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1016.8 MB/s | 1809.9 MB/s | **1.8x** | 2050.1 MB/s | 10368.9 MB/s | **5.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.1 MB/s | 1242.2 MB/s | **13.3x** | 1727.4 MB/s | 10014.3 MB/s | **5.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.2 MB/s | 1234.5 MB/s | **13.1x** | 2047.0 MB/s | 11020.3 MB/s | **5.4x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 16214.2 MB/s | 16294.1 MB/s | **1.0x** | 5632.0 MB/s | 4311.6 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 11058.7 MB/s | 18830.9 MB/s | **1.7x** | 5375.7 MB/s | 3509.6 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2180.7 MB/s | 9643.8 MB/s | **4.4x** | 1940.2 MB/s | 3217.7 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 1925.6 MB/s | 8275.6 MB/s | **4.3x** | 1967.2 MB/s | 3216.4 MB/s | **1.6x** | - |
