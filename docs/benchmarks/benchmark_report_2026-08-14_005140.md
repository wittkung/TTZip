# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-13 16:51:40 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 897.6 MB/s | 391.7 MB/s | **0.4x** | 740.8 MB/s | 607.2 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 856.3 MB/s | 243.5 MB/s | **0.3x** | 559.4 MB/s | 471.2 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 288.8 MB/s | 258.5 MB/s | **0.9x** | 618.1 MB/s | 568.8 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 290.7 MB/s | 222.7 MB/s | **0.8x** | 481.6 MB/s | 441.8 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 426.3 MB/s | 665.8 MB/s | **1.6x** | 588.3 MB/s | 2127.4 MB/s | **3.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 419.7 MB/s | 537.0 MB/s | **1.3x** | 292.9 MB/s | 246.3 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 364.7 MB/s | 616.6 MB/s | **1.7x** | 570.1 MB/s | 2151.9 MB/s | **3.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 340.9 MB/s | 519.2 MB/s | **1.5x** | 304.2 MB/s | 253.0 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 238.0 MB/s | 412.3 MB/s | **1.7x** | 261.7 MB/s | 933.3 MB/s | **3.6x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 281.9 MB/s | 403.5 MB/s | **1.4x** | 263.6 MB/s | 900.6 MB/s | **3.4x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1031.6 MB/s | 535.4 MB/s | **0.5x** | 1355.3 MB/s | 1769.7 MB/s | **1.3x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 932.5 MB/s | 287.0 MB/s | **0.3x** | 839.8 MB/s | 654.9 MB/s | **0.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 287.1 MB/s | 544.4 MB/s | **1.9x** | 970.9 MB/s | 1780.8 MB/s | **1.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 289.3 MB/s | 286.2 MB/s | **1.0x** | 666.0 MB/s | 654.9 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 668.6 MB/s | 1082.1 MB/s | **1.6x** | 959.1 MB/s | 6058.9 MB/s | **6.3x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 640.1 MB/s | 1039.4 MB/s | **1.6x** | 1004.3 MB/s | 757.4 MB/s | **0.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 76.9 MB/s | 870.5 MB/s | **11.3x** | 954.4 MB/s | 6208.7 MB/s | **6.5x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 78.5 MB/s | 851.6 MB/s | **10.8x** | 1027.0 MB/s | 773.4 MB/s | **0.8x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1666.0 MB/s | 1216.4 MB/s | **0.7x** | 1608.9 MB/s | 3731.3 MB/s | **2.3x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1268.6 MB/s | 1463.6 MB/s | **1.2x** | 1597.9 MB/s | 5906.0 MB/s | **3.7x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.3%) | 711.7 MB/s | 602.6 MB/s | **0.8x** | 902.8 MB/s | 4554.7 MB/s | **5.0x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 758.7 MB/s | 604.9 MB/s | **0.8x** | 923.0 MB/s | 4795.9 MB/s | **5.2x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 226.4 MB/s | 2605.6 MB/s | **11.5x** | 3735.7 MB/s | 5582.6 MB/s | **1.5x** | 2_SolidBuf_IO_and_CRC32 (96.9%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 213.0 MB/s | 177.2 MB/s | **0.8x** | 3115.3 MB/s | 1460.8 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 141.0 MB/s | 2536.2 MB/s | **18.0x** | 1592.1 MB/s | 6385.5 MB/s | **4.0x** | 2_SolidBuf_IO_and_CRC32 (96.0%) |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 141.6 MB/s | 186.0 MB/s | **1.3x** | 1370.9 MB/s | 1467.5 MB/s | **1.1x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 86.6 MB/s | 1740.9 MB/s | **20.1x** | 3171.5 MB/s | 9741.4 MB/s | **3.1x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 82.6 MB/s | 874.1 MB/s | **10.6x** | 1763.2 MB/s | 899.9 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 75.5 MB/s | 1748.2 MB/s | **23.2x** | 3704.6 MB/s | 9016.4 MB/s | **2.4x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 71.9 MB/s | 1106.9 MB/s | **15.4x** | 1821.0 MB/s | 929.8 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5673.2 MB/s | 1328.9 MB/s | **0.2x** | 6767.2 MB/s | 5875.0 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 5818.3 MB/s | 1512.9 MB/s | **0.3x** | 6829.8 MB/s | 7719.0 MB/s | **1.1x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 1006.1 MB/s | 78.7 MB/s | **0.1x** | 1615.2 MB/s | 5146.5 MB/s | **3.2x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 1012.2 MB/s | 79.4 MB/s | **0.1x** | 1566.5 MB/s | 4665.4 MB/s | **3.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5095.1 MB/s | 3385.0 MB/s | **0.7x** | 5022.4 MB/s | 2014.5 MB/s | **0.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5061.8 MB/s | 675.3 MB/s | **0.1x** | 4986.6 MB/s | 3547.1 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 676.7 MB/s | 3390.4 MB/s | **5.0x** | 3755.6 MB/s | 2037.3 MB/s | **0.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 680.0 MB/s | 680.5 MB/s | **1.0x** | 3195.7 MB/s | 3549.9 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1038.2 MB/s | 587.0 MB/s | **0.6x** | 1652.1 MB/s | 7354.2 MB/s | **4.5x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1034.0 MB/s | 570.7 MB/s | **0.6x** | 2066.3 MB/s | 1512.4 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 96.5 MB/s | 513.2 MB/s | **5.3x** | 1620.0 MB/s | 11847.7 MB/s | **7.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 98.0 MB/s | 504.5 MB/s | **5.1x** | 2114.1 MB/s | 1524.4 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 14171.1 MB/s | 1863.3 MB/s | **0.1x** | 5814.1 MB/s | 7507.2 MB/s | **1.3x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 9954.7 MB/s | 1361.2 MB/s | **0.1x** | 6785.8 MB/s | 9533.6 MB/s | **1.4x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 2218.2 MB/s | 615.2 MB/s | **0.3x** | 1939.2 MB/s | 3021.2 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 1980.2 MB/s | 611.4 MB/s | **0.3x** | 1682.8 MB/s | 3175.7 MB/s | **1.9x** | - |
