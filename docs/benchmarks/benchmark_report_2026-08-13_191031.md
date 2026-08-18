# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-13 11:10:31 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 630.6 MB/s | 201.0 MB/s | **0.3x** | 511.5 MB/s | 418.1 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 632.4 MB/s | 167.5 MB/s | **0.3x** | 389.8 MB/s | 330.7 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 199.3 MB/s | 278.5 MB/s | **1.4x** | 437.5 MB/s | 479.6 MB/s | **1.1x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 197.8 MB/s | 166.6 MB/s | **0.8x** | 329.7 MB/s | 324.4 MB/s | **1.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 318.9 MB/s | 444.3 MB/s | **1.4x** | 418.0 MB/s | 1610.2 MB/s | **3.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 314.7 MB/s | 387.1 MB/s | **1.2x** | 204.0 MB/s | 172.6 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 276.0 MB/s | 446.2 MB/s | **1.6x** | 400.2 MB/s | 1616.3 MB/s | **4.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 264.8 MB/s | 393.1 MB/s | **1.5x** | 202.1 MB/s | 175.5 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 187.4 MB/s | 271.6 MB/s | **1.4x** | 155.4 MB/s | 649.7 MB/s | **4.2x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 197.3 MB/s | 268.3 MB/s | **1.4x** | 177.8 MB/s | 524.0 MB/s | **2.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 780.1 MB/s | 358.8 MB/s | **0.5x** | 978.2 MB/s | 1202.6 MB/s | **1.2x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 673.5 MB/s | 199.7 MB/s | **0.3x** | 571.7 MB/s | 444.4 MB/s | **0.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 202.3 MB/s | 360.4 MB/s | **1.8x** | 672.7 MB/s | 1215.5 MB/s | **1.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 200.9 MB/s | 199.1 MB/s | **1.0x** | 449.4 MB/s | 436.4 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 453.2 MB/s | 717.2 MB/s | **1.6x** | 663.8 MB/s | 3729.5 MB/s | **5.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 440.8 MB/s | 680.0 MB/s | **1.5x** | 704.6 MB/s | 510.5 MB/s | **0.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 52.2 MB/s | 576.3 MB/s | **11.1x** | 655.1 MB/s | 4688.1 MB/s | **7.2x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 50.3 MB/s | 559.8 MB/s | **11.1x** | 722.1 MB/s | 529.9 MB/s | **0.7x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 916.4 MB/s | 1273.6 MB/s | **1.4x** | 1162.4 MB/s | 3242.3 MB/s | **2.8x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 914.5 MB/s | 971.7 MB/s | **1.1x** | 1123.6 MB/s | 3688.6 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.3%) | 567.7 MB/s | 397.1 MB/s | **0.7x** | 661.2 MB/s | 3345.9 MB/s | **5.1x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 570.6 MB/s | 396.5 MB/s | **0.7x** | 652.8 MB/s | 3594.4 MB/s | **5.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 172.5 MB/s | 1415.6 MB/s | **8.2x** | 2766.1 MB/s | 4136.7 MB/s | **1.5x** | 2_SolidBuf_IO_and_CRC32 (98.2%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 146.6 MB/s | 148.6 MB/s | **1.0x** | 2030.4 MB/s | 1020.9 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 115.6 MB/s | 1764.4 MB/s | **15.3x** | 1108.3 MB/s | 4472.1 MB/s | **4.0x** | 2_SolidBuf_IO_and_CRC32 (96.7%) |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 115.6 MB/s | 147.8 MB/s | **1.3x** | 991.6 MB/s | 1009.1 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 59.0 MB/s | 1257.2 MB/s | **21.3x** | 2579.6 MB/s | 7408.5 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 54.0 MB/s | 617.3 MB/s | **11.4x** | 1143.6 MB/s | 611.7 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 50.8 MB/s | 1299.6 MB/s | **25.6x** | 2586.8 MB/s | 7285.0 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 47.7 MB/s | 726.9 MB/s | **15.2x** | 1196.3 MB/s | 573.0 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4111.9 MB/s | 951.5 MB/s | **0.2x** | 4838.6 MB/s | 4357.4 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 4319.6 MB/s | 1057.7 MB/s | **0.2x** | 4724.4 MB/s | 6080.0 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 395.0 MB/s | 52.2 MB/s | **0.1x** | 897.4 MB/s | 3580.8 MB/s | **4.0x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 843.1 MB/s | 52.7 MB/s | **0.1x** | 1086.0 MB/s | 3692.2 MB/s | **3.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 4629.9 MB/s | 2633.1 MB/s | **0.6x** | 3788.3 MB/s | 1354.6 MB/s | **0.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4539.6 MB/s | 447.0 MB/s | **0.1x** | 3598.6 MB/s | 2514.0 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 451.6 MB/s | 2595.3 MB/s | **5.7x** | 2703.5 MB/s | 1351.3 MB/s | **0.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 458.1 MB/s | 450.6 MB/s | **1.0x** | 2568.1 MB/s | 2567.9 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 687.8 MB/s | 369.6 MB/s | **0.5x** | 1159.6 MB/s | 4903.4 MB/s | **4.2x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 681.0 MB/s | 367.7 MB/s | **0.5x** | 1391.5 MB/s | 1004.7 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 63.1 MB/s | 325.5 MB/s | **5.2x** | 1179.1 MB/s | 8917.6 MB/s | **7.6x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 63.1 MB/s | 330.9 MB/s | **5.2x** | 1391.9 MB/s | 976.0 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10660.9 MB/s | 1318.3 MB/s | **0.1x** | 4199.4 MB/s | 6219.3 MB/s | **1.5x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 7469.8 MB/s | 915.9 MB/s | **0.1x** | 4712.9 MB/s | 6982.4 MB/s | **1.5x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 1661.9 MB/s | 399.4 MB/s | **0.2x** | 1312.1 MB/s | 2177.2 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 1679.3 MB/s | 407.6 MB/s | **0.2x** | 1241.1 MB/s | 2144.2 MB/s | **1.7x** | - |
