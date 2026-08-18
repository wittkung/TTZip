# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-13 17:15:55 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 912.9 MB/s | 427.7 MB/s | **0.5x** | 675.4 MB/s | 558.6 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 849.4 MB/s | 241.2 MB/s | **0.3x** | 511.6 MB/s | 439.0 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 286.4 MB/s | 440.3 MB/s | **1.5x** | 629.0 MB/s | 602.3 MB/s | **1.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 285.9 MB/s | 241.5 MB/s | **0.8x** | 471.7 MB/s | 454.2 MB/s | **1.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 463.2 MB/s | 675.6 MB/s | **1.5x** | 588.0 MB/s | 1982.6 MB/s | **3.4x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 444.1 MB/s | 564.3 MB/s | **1.3x** | 299.2 MB/s | 236.2 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 372.2 MB/s | 665.2 MB/s | **1.8x** | 553.1 MB/s | 1839.3 MB/s | **3.3x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 360.8 MB/s | 570.4 MB/s | **1.6x** | 239.1 MB/s | 256.4 MB/s | **1.1x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 237.1 MB/s | 416.4 MB/s | **1.8x** | 267.7 MB/s | 695.5 MB/s | **2.6x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 244.1 MB/s | 408.7 MB/s | **1.7x** | 268.8 MB/s | 858.6 MB/s | **3.2x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1081.6 MB/s | 464.0 MB/s | **0.4x** | 1151.5 MB/s | 1918.0 MB/s | **1.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 964.7 MB/s | 285.0 MB/s | **0.3x** | 868.8 MB/s | 669.0 MB/s | **0.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 292.0 MB/s | 530.6 MB/s | **1.8x** | 1012.7 MB/s | 1746.2 MB/s | **1.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 287.7 MB/s | 286.6 MB/s | **1.0x** | 679.6 MB/s | 567.6 MB/s | **0.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 664.1 MB/s | 1071.1 MB/s | **1.6x** | 1003.5 MB/s | 6248.3 MB/s | **6.2x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 655.2 MB/s | 1090.8 MB/s | **1.7x** | 1011.8 MB/s | 761.3 MB/s | **0.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 76.9 MB/s | 873.4 MB/s | **11.4x** | 962.6 MB/s | 6576.6 MB/s | **6.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 80.1 MB/s | 860.5 MB/s | **10.7x** | 1036.1 MB/s | 748.2 MB/s | **0.7x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1515.0 MB/s | 1730.1 MB/s | **1.1x** | 1666.7 MB/s | 6363.0 MB/s | **3.8x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1245.6 MB/s | 1409.6 MB/s | **1.1x** | 1277.4 MB/s | 5497.3 MB/s | **4.3x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.3%) | 746.1 MB/s | 603.0 MB/s | **0.8x** | 893.8 MB/s | 5079.2 MB/s | **5.7x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 720.0 MB/s | 597.7 MB/s | **0.8x** | 887.0 MB/s | 5220.3 MB/s | **5.9x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 232.7 MB/s | 2070.5 MB/s | **8.9x** | 4253.7 MB/s | 7274.9 MB/s | **1.7x** | 2_SolidBuf_IO_and_CRC32 (98.6%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 222.4 MB/s | 192.0 MB/s | **0.9x** | 3267.8 MB/s | 1513.0 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 141.4 MB/s | 2630.9 MB/s | **18.6x** | 1459.4 MB/s | 6563.9 MB/s | **4.5x** | 2_SolidBuf_IO_and_CRC32 (97.3%) |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 142.5 MB/s | 182.6 MB/s | **1.3x** | 1539.0 MB/s | 1440.1 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 87.9 MB/s | 1892.9 MB/s | **21.5x** | 3208.7 MB/s | 9367.8 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 82.2 MB/s | 875.8 MB/s | **10.7x** | 1891.3 MB/s | 956.0 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 75.3 MB/s | 1961.5 MB/s | **26.1x** | 3518.8 MB/s | 10958.4 MB/s | **3.1x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.4 MB/s | 1075.8 MB/s | **15.3x** | 1795.6 MB/s | 917.1 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5506.9 MB/s | 1216.9 MB/s | **0.2x** | 6351.5 MB/s | 5721.6 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 5937.1 MB/s | 1297.3 MB/s | **0.2x** | 6830.0 MB/s | 7950.3 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 967.5 MB/s | 76.8 MB/s | **0.1x** | 1570.3 MB/s | 5402.9 MB/s | **3.4x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 1019.0 MB/s | 79.6 MB/s | **0.1x** | 1713.9 MB/s | 5264.0 MB/s | **3.1x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5331.9 MB/s | 3539.8 MB/s | **0.7x** | 5439.4 MB/s | 2101.5 MB/s | **0.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5146.9 MB/s | 609.4 MB/s | **0.1x** | 4896.4 MB/s | 3572.4 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 674.8 MB/s | 3232.0 MB/s | **4.8x** | 3724.1 MB/s | 2001.9 MB/s | **0.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 676.1 MB/s | 668.9 MB/s | **1.0x** | 3511.2 MB/s | 3471.0 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1024.4 MB/s | 579.9 MB/s | **0.6x** | 1712.6 MB/s | 7003.2 MB/s | **4.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1030.6 MB/s | 567.1 MB/s | **0.6x** | 2014.9 MB/s | 1458.4 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 95.2 MB/s | 501.3 MB/s | **5.3x** | 1733.8 MB/s | 11653.2 MB/s | **6.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 96.0 MB/s | 507.0 MB/s | **5.3x** | 2031.1 MB/s | 1488.5 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 16251.7 MB/s | 1890.2 MB/s | **0.1x** | 5939.3 MB/s | 7854.2 MB/s | **1.3x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10433.0 MB/s | 1351.4 MB/s | **0.1x** | 6369.1 MB/s | 9321.9 MB/s | **1.5x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 2103.8 MB/s | 611.9 MB/s | **0.3x** | 1928.3 MB/s | 3265.7 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 2019.1 MB/s | 607.0 MB/s | **0.3x** | 1945.8 MB/s | 3149.6 MB/s | **1.6x** | - |
