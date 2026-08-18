# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-13 17:19:21 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 835.0 MB/s | 430.1 MB/s | **0.5x** | 711.5 MB/s | 748.3 MB/s | **1.1x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 728.3 MB/s | 239.3 MB/s | **0.3x** | 533.0 MB/s | 397.6 MB/s | **0.7x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 291.1 MB/s | 414.9 MB/s | **1.4x** | 603.7 MB/s | 704.0 MB/s | **1.2x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 274.9 MB/s | 234.9 MB/s | **0.9x** | 428.7 MB/s | 433.5 MB/s | **1.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 404.7 MB/s | 640.0 MB/s | **1.6x** | 574.3 MB/s | 2198.9 MB/s | **3.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 424.9 MB/s | 557.0 MB/s | **1.3x** | 255.2 MB/s | 246.8 MB/s | **1.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 371.5 MB/s | 449.4 MB/s | **1.2x** | 424.2 MB/s | 1571.4 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 354.7 MB/s | 379.0 MB/s | **1.1x** | 264.9 MB/s | 227.8 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 260.2 MB/s | 406.3 MB/s | **1.6x** | 267.7 MB/s | 975.1 MB/s | **3.6x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 263.4 MB/s | 393.0 MB/s | **1.5x** | 218.0 MB/s | 825.3 MB/s | **3.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1071.3 MB/s | 522.8 MB/s | **0.5x** | 1375.6 MB/s | 1832.1 MB/s | **1.3x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 940.0 MB/s | 292.2 MB/s | **0.3x** | 825.0 MB/s | 653.8 MB/s | **0.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 297.7 MB/s | 525.5 MB/s | **1.8x** | 965.6 MB/s | 1807.8 MB/s | **1.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 293.9 MB/s | 293.6 MB/s | **1.0x** | 663.9 MB/s | 631.5 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 656.3 MB/s | 1034.9 MB/s | **1.6x** | 964.9 MB/s | 6606.6 MB/s | **6.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 646.9 MB/s | 1060.9 MB/s | **1.6x** | 1068.8 MB/s | 775.5 MB/s | **0.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 77.1 MB/s | 877.7 MB/s | **11.4x** | 892.9 MB/s | 7430.0 MB/s | **8.3x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 74.4 MB/s | 843.7 MB/s | **11.3x** | 757.3 MB/s | 787.8 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1491.5 MB/s | 1476.3 MB/s | **1.0x** | 1493.9 MB/s | 5305.1 MB/s | **3.6x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1266.0 MB/s | 1217.7 MB/s | **1.0x** | 1514.5 MB/s | 5348.0 MB/s | **3.5x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.3%) | 636.4 MB/s | 595.1 MB/s | **0.9x** | 897.6 MB/s | 5101.9 MB/s | **5.7x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 745.6 MB/s | 591.2 MB/s | **0.8x** | 904.7 MB/s | 5434.0 MB/s | **6.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 224.6 MB/s | 2646.4 MB/s | **11.8x** | 4248.0 MB/s | 7033.4 MB/s | **1.7x** | 2_SolidBuf_IO_and_CRC32 (96.9%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 208.3 MB/s | 191.9 MB/s | **0.9x** | 3318.8 MB/s | 1536.8 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 148.2 MB/s | 2635.9 MB/s | **17.8x** | 1657.3 MB/s | 6733.4 MB/s | **4.1x** | 2_SolidBuf_IO_and_CRC32 (96.8%) |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 147.7 MB/s | 192.9 MB/s | **1.3x** | 1472.5 MB/s | 1536.8 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 88.8 MB/s | 1562.6 MB/s | **17.6x** | 3779.6 MB/s | 10218.2 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 75.7 MB/s | 842.9 MB/s | **11.1x** | 1712.4 MB/s | 863.8 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 73.1 MB/s | 1820.3 MB/s | **24.9x** | 4003.9 MB/s | 9458.8 MB/s | **2.4x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 66.9 MB/s | 1113.8 MB/s | **16.6x** | 1717.8 MB/s | 925.7 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5421.4 MB/s | 1294.5 MB/s | **0.2x** | 6762.8 MB/s | 5825.1 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 5236.8 MB/s | 1529.0 MB/s | **0.3x** | 6973.3 MB/s | 8794.8 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 949.4 MB/s | 75.5 MB/s | **0.1x** | 999.7 MB/s | 3479.1 MB/s | **3.5x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 901.7 MB/s | 73.9 MB/s | **0.1x** | 1399.0 MB/s | 5725.9 MB/s | **4.1x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5270.1 MB/s | 3434.2 MB/s | **0.7x** | 5583.0 MB/s | 2035.2 MB/s | **0.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4836.4 MB/s | 571.2 MB/s | **0.1x** | 4430.8 MB/s | 3099.5 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 657.2 MB/s | 2202.2 MB/s | **3.4x** | 3526.7 MB/s | 1469.0 MB/s | **0.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 657.0 MB/s | 655.2 MB/s | **1.0x** | 3485.0 MB/s | 3255.3 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 995.2 MB/s | 556.9 MB/s | **0.6x** | 1649.5 MB/s | 6981.9 MB/s | **4.2x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 992.9 MB/s | 531.7 MB/s | **0.5x** | 1904.3 MB/s | 1330.2 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 90.0 MB/s | 487.0 MB/s | **5.4x** | 1475.8 MB/s | 11130.9 MB/s | **7.5x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 89.8 MB/s | 459.0 MB/s | **5.1x** | 1829.0 MB/s | 1144.8 MB/s | **0.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 12425.8 MB/s | 1604.5 MB/s | **0.1x** | 4878.0 MB/s | 7567.8 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 9780.2 MB/s | 1287.6 MB/s | **0.1x** | 5412.0 MB/s | 9722.8 MB/s | **1.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 1670.1 MB/s | 584.5 MB/s | **0.3x** | 1066.1 MB/s | 3000.3 MB/s | **2.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 1969.3 MB/s | 473.4 MB/s | **0.2x** | 1327.2 MB/s | 2946.2 MB/s | **2.2x** | - |
