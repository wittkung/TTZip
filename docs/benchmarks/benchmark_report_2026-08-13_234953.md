# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-13 15:49:53 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS Version 26.6 (Build 25G72)
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 1076.1 MB/s | 327.7 MB/s | **0.3x** | 400.4 MB/s | 480.0 MB/s | **1.2x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 873.4 MB/s | 326.8 MB/s | **0.4x** | 328.7 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 293.7 MB/s | 442.4 MB/s | **1.5x** | 470.5 MB/s | 372.2 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 291.3 MB/s | 352.2 MB/s | **1.2x** | 308.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 462.9 MB/s | 616.1 MB/s | **1.3x** | 423.0 MB/s | 721.4 MB/s | **1.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 444.6 MB/s | 553.8 MB/s | **1.2x** | 230.1 MB/s | 867.6 MB/s | **3.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 9 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 217.6 MB/s | 533.9 MB/s | **2.5x** | 601.1 MB/s | 912.4 MB/s | **1.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 9 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 207.0 MB/s | 560.7 MB/s | **2.7x** | 293.2 MB/s | 1065.8 MB/s | **3.6x** | - |
| 海量小文件 (10MB/100文件) | TAR | 1 | 无 | 7-Zip 7zz CLI | 11.92 MB (100.8%) | 11.92 MB (100.8%) | 1762.7 MB/s | 717.7 MB/s | **0.4x** | 731.1 MB/s | 353.1 MB/s | **0.5x** | - |
| 海量小文件 (10MB/100文件) | TAR | 1 | 无 | BSD tar (Native) | 12.11 MB (102.4%) | 11.92 MB (100.8%) | 247.5 MB/s | 717.7 MB/s | **2.9x** | 225.2 MB/s | 353.1 MB/s | **1.6x** | - |
| 海量小文件 (10MB/100文件) | TAR | 9 | 无 | 7-Zip 7zz CLI | 11.92 MB (100.8%) | 11.92 MB (100.8%) | 1492.7 MB/s | 695.9 MB/s | **0.5x** | 754.0 MB/s | 339.9 MB/s | **0.5x** | - |
| 海量小文件 (10MB/100文件) | TAR | 9 | 无 | BSD tar (Native) | 12.11 MB (102.4%) | 11.92 MB (100.8%) | 242.6 MB/s | 695.9 MB/s | **2.9x** | 267.8 MB/s | 339.9 MB/s | **1.3x** | - |
| 海量小文件 (10MB/100文件) | GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.06 MB (0.5%) | 243.7 MB/s | 484.1 MB/s | **2.0x** | 259.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | GZ | 9 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.05 MB (0.5%) | 246.7 MB/s | 654.8 MB/s | **2.7x** | 249.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | BZ2 | 1 | 无 | pbzip2 (All Cores) | 0.07 MB (0.6%) | 0.06 MB (0.5%) | 75.8 MB/s | 662.7 MB/s | **8.7x** | 184.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | BZ2 | 9 | 无 | pbzip2 (All Cores) | 0.02 MB (0.1%) | 0.05 MB (0.5%) | 55.8 MB/s | 603.6 MB/s | **10.8x** | 126.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | XZ | 1 | 无 | pixz (Parallel XZ) | 0.01 MB (0.1%) | 0.06 MB (0.5%) | 220.1 MB/s | 667.1 MB/s | **3.0x** | 243.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | XZ | 9 | 无 | pixz (Parallel XZ) | 0.01 MB (0.0%) | 0.05 MB (0.5%) | 100.1 MB/s | 664.9 MB/s | **6.6x** | 230.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | LZIP | 1 | 无 | plzip (Multi-thread Lzip) | 0.01 MB (0.1%) | 0.06 MB (0.5%) | 168.5 MB/s | 477.0 MB/s | **2.8x** | 213.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | LZIP | 9 | 无 | plzip (Multi-thread Lzip) | 0.00 MB (0.0%) | 0.05 MB (0.5%) | 9.9 MB/s | 666.7 MB/s | **67.1x** | 156.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | LZ4 | 1 | 无 | official lz4 CLI | 0.10 MB (0.9%) | 0.06 MB (0.5%) | 277.8 MB/s | 686.1 MB/s | **2.5x** | 265.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | LZ4 | 9 | 无 | official lz4 CLI | 0.09 MB (0.8%) | 0.05 MB (0.5%) | 113.2 MB/s | 681.1 MB/s | **6.0x** | 260.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | BROTLI | 1 | 无 | brotli CLI | 0.02 MB (0.2%) | 0.06 MB (0.5%) | 184.7 MB/s | 693.2 MB/s | **3.8x** | 253.7 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | BROTLI | 9 | 无 | brotli CLI | 0.00 MB (0.0%) | 0.05 MB (0.5%) | 236.6 MB/s | 662.8 MB/s | **2.8x** | 250.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | LRZIP | 1 | 无 | lrzip (Multi-core) | 0.00 MB (0.0%) | 0.06 MB (0.5%) | 147.2 MB/s | 670.8 MB/s | **4.6x** | 171.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | LRZIP | 9 | 无 | lrzip (Multi-core) | 0.00 MB (0.0%) | 0.05 MB (0.5%) | 109.1 MB/s | 517.3 MB/s | **4.7x** | 174.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | AAR | 1 | 无 | Apple aa (AppleArchive LZFSE) | 0.01 MB (0.1%) | 0.06 MB (0.5%) | 570.7 MB/s | 681.9 MB/s | **1.2x** | 929.7 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | AAR | 9 | 无 | Apple aa (AppleArchive LZFSE) | 0.01 MB (0.1%) | 0.05 MB (0.5%) | 591.7 MB/s | 679.4 MB/s | **1.1x** | 904.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | WIM | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.06 MB (0.5%) | 1097.5 MB/s | 696.8 MB/s | **0.6x** | 764.7 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | WIM | 1 | 无 | wimlib-imagex | 0.00 MB (0.0%) | 0.06 MB (0.5%) | 822.8 MB/s | 696.8 MB/s | **0.8x** | 943.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | WIM | 1 | AES-256 | wimlib-imagex | 0.00 MB (0.0%) | 0.06 MB (0.5%) | 1131.8 MB/s | 405.2 MB/s | **0.4x** | 916.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | WIM | 9 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.05 MB (0.5%) | 310.4 MB/s | 686.0 MB/s | **2.2x** | 371.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | WIM | 9 | 无 | wimlib-imagex | 0.00 MB (0.0%) | 0.05 MB (0.5%) | 1074.8 MB/s | 686.0 MB/s | **0.6x** | 1147.6 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | WIM | 9 | AES-256 | wimlib-imagex | 0.00 MB (0.0%) | 0.06 MB (0.5%) | 1125.3 MB/s | 567.7 MB/s | **0.5x** | 1283.7 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | DMG | 1 | 无 | macOS hdiutil (DMG) | 0.11 MB (1.0%) | 0.06 MB (0.5%) | 2.3 MB/s | 688.6 MB/s | **293.3x** | 277.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | DMG | 1 | AES-256 | macOS hdiutil (DMG) | 0.11 MB (1.0%) | 0.06 MB (0.5%) | 2.3 MB/s | 520.4 MB/s | **221.5x** | 234.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | DMG | 9 | 无 | macOS hdiutil (DMG) | 0.11 MB (1.0%) | 0.05 MB (0.5%) | 2.9 MB/s | 626.4 MB/s | **213.2x** | 305.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | DMG | 9 | AES-256 | macOS hdiutil (DMG) | 0.11 MB (1.0%) | 0.06 MB (0.5%) | 2.9 MB/s | 423.7 MB/s | **144.2x** | 233.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | ISO | 1 | 无 | macOS hdiutil (ISO) | 11.99 MB (101.4%) | 0.06 MB (0.5%) | 454.1 MB/s | 589.9 MB/s | **1.3x** | 955.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | ISO | 9 | 无 | macOS hdiutil (ISO) | 11.99 MB (101.4%) | 0.05 MB (0.5%) | 486.8 MB/s | 694.9 MB/s | **1.4x** | 1106.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1074.4 MB/s | 495.2 MB/s | **0.5x** | 1585.3 MB/s | 1731.1 MB/s | **1.1x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1185.8 MB/s | 404.6 MB/s | **0.3x** | 1060.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 306.9 MB/s | 545.5 MB/s | **1.8x** | 1327.0 MB/s | 1640.1 MB/s | **1.2x** | - |
| 拟真日志文本 (10MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 302.1 MB/s | 411.8 MB/s | **1.4x** | 809.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 613.4 MB/s | 1116.7 MB/s | **1.8x** | 1105.1 MB/s | 5534.0 MB/s | **5.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 782.2 MB/s | 1059.2 MB/s | **1.4x** | 1445.8 MB/s | 4284.5 MB/s | **3.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 9 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 24.6 MB/s | 898.6 MB/s | **36.5x** | 1271.8 MB/s | 5946.2 MB/s | **4.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 9 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 23.7 MB/s | 880.3 MB/s | **37.2x** | 1366.1 MB/s | 4398.1 MB/s | **3.2x** | - |
| 拟真日志文本 (10MB) | TAR | 1 | 无 | 7-Zip 7zz CLI | 11.16 MB (100.0%) | 11.16 MB (100.0%) | 2645.0 MB/s | 1583.7 MB/s | **0.6x** | 2959.9 MB/s | 4807.8 MB/s | **1.6x** | - |
| 拟真日志文本 (10MB) | TAR | 1 | 无 | BSD tar (Native) | 11.16 MB (100.0%) | 11.16 MB (100.0%) | 1207.0 MB/s | 1583.7 MB/s | **1.3x** | 1473.6 MB/s | 4807.8 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | TAR | 9 | 无 | 7-Zip 7zz CLI | 11.16 MB (100.0%) | 11.16 MB (100.0%) | 2755.1 MB/s | 1522.7 MB/s | **0.6x** | 3074.4 MB/s | 4175.0 MB/s | **1.4x** | - |
| 拟真日志文本 (10MB) | TAR | 9 | 无 | BSD tar (Native) | 11.16 MB (100.0%) | 11.16 MB (100.0%) | 1169.0 MB/s | 1522.7 MB/s | **1.3x** | 1513.3 MB/s | 4175.0 MB/s | **2.8x** | - |
| 拟真日志文本 (10MB) | ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 2386.5 MB/s | 1752.0 MB/s | **0.7x** | 2631.6 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | ZST | 9 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 937.2 MB/s | 1141.4 MB/s | **1.2x** | 1611.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 1160.1 MB/s | 1038.2 MB/s | **0.9x** | 961.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | GZ | 9 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 1468.4 MB/s | 886.0 MB/s | **0.6x** | 1069.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | BZ2 | 1 | 无 | pbzip2 (All Cores) | 0.04 MB (0.3%) | 0.04 MB (0.4%) | 108.6 MB/s | 1077.1 MB/s | **9.9x** | 224.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | BZ2 | 9 | 无 | pbzip2 (All Cores) | 0.01 MB (0.1%) | 0.04 MB (0.3%) | 77.8 MB/s | 845.5 MB/s | **10.9x** | 190.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | XZ | 1 | 无 | pixz (Parallel XZ) | 0.00 MB (0.0%) | 0.04 MB (0.4%) | 616.1 MB/s | 1101.8 MB/s | **1.8x** | 845.7 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | XZ | 9 | 无 | pixz (Parallel XZ) | 0.00 MB (0.0%) | 0.04 MB (0.3%) | 157.1 MB/s | 865.2 MB/s | **5.5x** | 623.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | LZIP | 1 | 无 | plzip (Multi-thread Lzip) | 0.00 MB (0.0%) | 0.04 MB (0.4%) | 339.1 MB/s | 1054.3 MB/s | **3.1x** | 529.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | LZIP | 9 | 无 | plzip (Multi-thread Lzip) | 0.00 MB (0.0%) | 0.04 MB (0.3%) | 11.3 MB/s | 892.2 MB/s | **78.8x** | 267.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | LZ4 | 1 | 无 | official lz4 CLI | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 871.3 MB/s | 1104.9 MB/s | **1.3x** | 915.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | LZ4 | 9 | 无 | official lz4 CLI | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 850.2 MB/s | 887.3 MB/s | **1.0x** | 937.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | BROTLI | 1 | 无 | brotli CLI | 0.01 MB (0.1%) | 0.04 MB (0.4%) | 758.9 MB/s | 871.8 MB/s | **1.1x** | 730.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | BROTLI | 9 | 无 | brotli CLI | 0.00 MB (0.0%) | 0.04 MB (0.3%) | 595.3 MB/s | 868.6 MB/s | **1.5x** | 731.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | LRZIP | 1 | 无 | lrzip (Multi-core) | 0.00 MB (0.0%) | 0.04 MB (0.4%) | 319.7 MB/s | 1090.5 MB/s | **3.4x** | 361.6 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | LRZIP | 9 | 无 | lrzip (Multi-core) | 0.00 MB (0.0%) | 0.04 MB (0.3%) | 252.4 MB/s | 903.0 MB/s | **3.6x** | 352.6 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | WIM | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.04 MB (0.4%) | 1367.6 MB/s | 1042.2 MB/s | **0.8x** | 1984.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | WIM | 9 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.04 MB (0.3%) | 309.8 MB/s | 890.7 MB/s | **2.9x** | 1362.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | DMG | 1 | 无 | macOS hdiutil (DMG) | 0.10 MB (0.9%) | 0.04 MB (0.4%) | 2.8 MB/s | 1068.3 MB/s | **385.5x** | 470.7 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | DMG | 1 | AES-256 | macOS hdiutil (DMG) | 0.10 MB (0.9%) | 0.04 MB (0.4%) | 2.2 MB/s | 892.9 MB/s | **402.6x** | 339.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | DMG | 9 | 无 | macOS hdiutil (DMG) | 0.10 MB (0.9%) | 0.04 MB (0.3%) | 2.2 MB/s | 680.1 MB/s | **306.8x** | 371.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | DMG | 9 | AES-256 | macOS hdiutil (DMG) | 0.10 MB (0.9%) | 0.04 MB (0.3%) | 2.2 MB/s | 612.8 MB/s | **276.4x** | 340.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 238.9 MB/s | 2558.0 MB/s | **10.7x** | 4484.5 MB/s | 5590.1 MB/s | **1.2x** | 2_SolidBuf_IO_and_CRC32 (96.5%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 229.4 MB/s | 2528.1 MB/s | **11.0x** | 3395.7 MB/s | 5573.1 MB/s | **1.6x** | 2_SolidBuf_IO_and_CRC32 (96.4%) |
| 高熵物理Payload (100MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 136.5 MB/s | 2576.6 MB/s | **18.9x** | 1803.0 MB/s | 5179.8 MB/s | **2.9x** | 2_SolidBuf_IO_and_CRC32 (96.5%) |
| 高熵物理Payload (100MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 135.7 MB/s | 2579.8 MB/s | **19.0x** | 1592.1 MB/s | 5574.8 MB/s | **3.5x** | 2_SolidBuf_IO_and_CRC32 (96.6%) |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 89.6 MB/s | 1864.5 MB/s | **20.8x** | 4173.3 MB/s | 9517.8 MB/s | **2.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 86.4 MB/s | 925.1 MB/s | **10.7x** | 1968.5 MB/s | 2361.3 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 9 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5.1 MB/s | 1942.4 MB/s | **380.9x** | 4074.8 MB/s | 9705.0 MB/s | **2.4x** | - |
| 高熵物理Payload (100MB) | ZIP | 9 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5.1 MB/s | 1077.0 MB/s | **212.5x** | 1839.7 MB/s | 2321.4 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR | 1 | 无 | 7-Zip 7zz CLI | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5981.7 MB/s | 1628.7 MB/s | **0.3x** | 5159.9 MB/s | 6429.6 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | TAR | 1 | 无 | BSD tar (Native) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 2132.0 MB/s | 1628.7 MB/s | **0.8x** | 2244.2 MB/s | 6429.6 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | TAR | 9 | 无 | 7-Zip 7zz CLI | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 6340.6 MB/s | 1582.8 MB/s | **0.2x** | 7163.7 MB/s | 5484.6 MB/s | **0.8x** | - |
| 高熵物理Payload (100MB) | TAR | 9 | 无 | BSD tar (Native) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 2087.9 MB/s | 1582.8 MB/s | **0.8x** | 2218.7 MB/s | 5484.6 MB/s | **2.5x** | - |
| 高熵物理Payload (100MB) | ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 6676.4 MB/s | 1147.1 MB/s | **0.2x** | 8522.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | ZST | 9 | 无 | Zstandard zstd (Thread=0) | 1.01 MB (1.0%) | 1.01 MB (1.0%) | 4664.2 MB/s | 1302.6 MB/s | **0.3x** | 7098.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.00 MB (100.0%) | 1050.4 MB/s | 1928.7 MB/s | **1.8x** | 1992.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | GZ | 9 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.00 MB (100.0%) | 937.3 MB/s | 1924.6 MB/s | **2.1x** | 2026.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | BZ2 | 1 | 无 | pbzip2 (All Cores) | 100.81 MB (100.8%) | 100.00 MB (100.0%) | 235.3 MB/s | 1875.9 MB/s | **8.0x** | 514.6 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | BZ2 | 9 | 无 | pbzip2 (All Cores) | 100.45 MB (100.5%) | 100.00 MB (100.0%) | 222.5 MB/s | 1896.1 MB/s | **8.5x** | 369.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | XZ | 1 | 无 | pixz (Parallel XZ) | 50.03 MB (50.0%) | 100.00 MB (100.0%) | 181.3 MB/s | 1847.1 MB/s | **10.2x** | 1478.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | XZ | 9 | 无 | pixz (Parallel XZ) | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 40.5 MB/s | 1811.7 MB/s | **44.8x** | 1185.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | LZIP | 1 | 无 | plzip (Multi-thread Lzip) | 50.70 MB (50.7%) | 100.00 MB (100.0%) | 93.0 MB/s | 1887.9 MB/s | **20.3x** | 436.7 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | LZIP | 9 | 无 | plzip (Multi-thread Lzip) | 2.04 MB (2.0%) | 100.00 MB (100.0%) | 9.1 MB/s | 1871.6 MB/s | **205.3x** | 492.6 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | LZ4 | 1 | 无 | official lz4 CLI | 100.39 MB (100.4%) | 100.00 MB (100.0%) | 3139.6 MB/s | 1735.3 MB/s | **0.6x** | 1787.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | LZ4 | 9 | 无 | official lz4 CLI | 100.39 MB (100.4%) | 100.00 MB (100.0%) | 648.9 MB/s | 1880.0 MB/s | **2.9x** | 1750.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | BROTLI | 1 | 无 | brotli CLI | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 2284.0 MB/s | 1895.0 MB/s | **0.8x** | 1650.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | BROTLI | 9 | 无 | brotli CLI | 1.00 MB (1.0%) | 100.00 MB (100.0%) | 965.6 MB/s | 1903.5 MB/s | **2.0x** | 987.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | LRZIP | 1 | 无 | lrzip (Multi-core) | 1.01 MB (1.0%) | 100.00 MB (100.0%) | 335.9 MB/s | 1903.8 MB/s | **5.7x** | 410.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | LRZIP | 9 | 无 | lrzip (Multi-core) | 1.01 MB (1.0%) | 100.00 MB (100.0%) | 304.8 MB/s | 1848.9 MB/s | **6.1x** | 395.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | WIM | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 238.4 MB/s | 1857.9 MB/s | **7.8x** | 4589.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | WIM | 9 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 189.5 MB/s | 1867.2 MB/s | **9.9x** | 1753.6 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | DMG | 1 | 无 | macOS hdiutil (DMG) | 101.96 MB (102.0%) | 100.00 MB (100.0%) | 16.6 MB/s | 1896.7 MB/s | **114.5x** | 1844.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | DMG | 1 | AES-256 | macOS hdiutil (DMG) | 101.96 MB (102.0%) | 100.00 MB (100.0%) | 16.6 MB/s | 1042.7 MB/s | **62.9x** | 1744.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | DMG | 9 | 无 | macOS hdiutil (DMG) | 101.96 MB (102.0%) | 100.00 MB (100.0%) | 16.6 MB/s | 1826.3 MB/s | **110.2x** | 1788.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | DMG | 9 | AES-256 | macOS hdiutil (DMG) | 101.96 MB (102.0%) | 100.00 MB (100.0%) | 16.6 MB/s | 1051.1 MB/s | **63.5x** | 1624.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5151.8 MB/s | 3345.2 MB/s | **0.6x** | 5421.9 MB/s | 1990.1 MB/s | **0.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5120.2 MB/s | 3176.9 MB/s | **0.6x** | 4931.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 683.1 MB/s | 3365.0 MB/s | **4.9x** | 3931.0 MB/s | 1782.0 MB/s | **0.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 681.7 MB/s | 3220.9 MB/s | **4.7x** | 3702.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1044.2 MB/s | 591.8 MB/s | **0.6x** | 1832.2 MB/s | 6741.5 MB/s | **3.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1046.3 MB/s | 587.6 MB/s | **0.6x** | 2098.4 MB/s | 9740.3 MB/s | **4.6x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 9 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 26.6 MB/s | 509.6 MB/s | **19.1x** | 1787.4 MB/s | 11703.7 MB/s | **6.5x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 9 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 26.6 MB/s | 514.5 MB/s | **19.3x** | 2071.3 MB/s | 10790.9 MB/s | **5.2x** | - |
| 500MB 大文件数据块 (500MB) | TAR | 1 | 无 | 7-Zip 7zz CLI | 500.00 MB (100.0%) | 500.00 MB (100.0%) | 6586.2 MB/s | 1878.6 MB/s | **0.3x** | 7414.9 MB/s | 6313.8 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR | 1 | 无 | BSD tar (Native) | 500.00 MB (100.0%) | 500.00 MB (100.0%) | 2374.1 MB/s | 1878.6 MB/s | **0.8x** | 2425.3 MB/s | 6313.8 MB/s | **2.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR | 9 | 无 | 7-Zip 7zz CLI | 500.00 MB (100.0%) | 500.00 MB (100.0%) | 7561.5 MB/s | 1980.3 MB/s | **0.3x** | 7129.5 MB/s | 7293.6 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | TAR | 9 | 无 | BSD tar (Native) | 500.00 MB (100.0%) | 500.00 MB (100.0%) | 2549.5 MB/s | 1980.3 MB/s | **0.8x** | 2327.1 MB/s | 7293.6 MB/s | **3.1x** | - |
| 500MB 大文件数据块 (500MB) | ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 14923.4 MB/s | 1899.4 MB/s | **0.1x** | 6638.7 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | ZST | 9 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 8937.5 MB/s | 1071.5 MB/s | **0.1x** | 7015.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.58 MB (0.1%) | 4591.1 MB/s | 574.5 MB/s | **0.1x** | 2530.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | GZ | 9 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.51 MB (0.1%) | 5713.9 MB/s | 511.4 MB/s | **0.1x** | 2684.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | BZ2 | 1 | 无 | pbzip2 (All Cores) | 0.03 MB (0.0%) | 0.58 MB (0.1%) | 2169.4 MB/s | 577.8 MB/s | **0.3x** | 2006.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | BZ2 | 9 | 无 | pbzip2 (All Cores) | 0.03 MB (0.0%) | 0.51 MB (0.1%) | 2496.4 MB/s | 500.6 MB/s | **0.2x** | 1974.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | XZ | 1 | 无 | pixz (Parallel XZ) | 0.10 MB (0.0%) | 0.58 MB (0.1%) | 3303.4 MB/s | 583.9 MB/s | **0.2x** | 1956.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | XZ | 9 | 无 | pixz (Parallel XZ) | 0.07 MB (0.0%) | 0.51 MB (0.1%) | 663.6 MB/s | 511.5 MB/s | **0.8x** | 1538.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | LZIP | 1 | 无 | plzip (Multi-thread Lzip) | 0.10 MB (0.0%) | 0.58 MB (0.1%) | 1566.2 MB/s | 578.9 MB/s | **0.4x** | 1584.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | LZIP | 9 | 无 | plzip (Multi-thread Lzip) | 0.07 MB (0.0%) | 0.51 MB (0.1%) | 72.1 MB/s | 505.2 MB/s | **7.0x** | 1254.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | LZ4 | 1 | 无 | official lz4 CLI | 1.96 MB (0.4%) | 0.58 MB (0.1%) | 4118.3 MB/s | 579.4 MB/s | **0.1x** | 1934.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | LZ4 | 9 | 无 | official lz4 CLI | 1.96 MB (0.4%) | 0.51 MB (0.1%) | 4208.6 MB/s | 503.3 MB/s | **0.1x** | 1970.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | BROTLI | 1 | 无 | brotli CLI | 0.09 MB (0.0%) | 0.58 MB (0.1%) | 3817.5 MB/s | 575.7 MB/s | **0.2x** | 1654.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | BROTLI | 9 | 无 | brotli CLI | 0.00 MB (0.0%) | 0.51 MB (0.1%) | 980.3 MB/s | 497.0 MB/s | **0.5x** | 1172.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | LRZIP | 1 | 无 | lrzip (Multi-core) | 0.07 MB (0.0%) | 0.58 MB (0.1%) | 223.0 MB/s | 588.0 MB/s | **2.6x** | 419.7 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | LRZIP | 9 | 无 | lrzip (Multi-core) | 0.07 MB (0.0%) | 0.51 MB (0.1%) | 169.3 MB/s | 505.1 MB/s | **3.0x** | 422.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | WIM | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.58 MB (0.1%) | 5180.0 MB/s | 583.1 MB/s | **0.1x** | 5392.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | WIM | 9 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.51 MB (0.1%) | 648.0 MB/s | 506.1 MB/s | **0.8x** | 3821.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | DMG | 1 | 无 | macOS hdiutil (DMG) | 0.06 MB (0.0%) | 0.58 MB (0.1%) | 99.4 MB/s | 580.1 MB/s | **5.8x** | 6059.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | DMG | 1 | AES-256 | macOS hdiutil (DMG) | 0.06 MB (0.0%) | 0.58 MB (0.1%) | 82.8 MB/s | 596.1 MB/s | **7.2x** | 6266.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | DMG | 9 | 无 | macOS hdiutil (DMG) | 0.06 MB (0.0%) | 0.51 MB (0.1%) | 99.4 MB/s | 505.3 MB/s | **5.1x** | 6681.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | DMG | 9 | AES-256 | macOS hdiutil (DMG) | 0.06 MB (0.0%) | 0.51 MB (0.1%) | 99.4 MB/s | 515.1 MB/s | **5.2x** | 8158.8 MB/s | 0.0 MB/s | **0.0x** | - |
