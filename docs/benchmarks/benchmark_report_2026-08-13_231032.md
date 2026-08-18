# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-13 15:10:32 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS Version 26.6 (Build 25G72)
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 796.5 MB/s | 206.8 MB/s | **0.3x** | 520.6 MB/s | 322.5 MB/s | **0.6x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 793.3 MB/s | 175.2 MB/s | **0.2x** | 383.1 MB/s | 312.4 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 206.5 MB/s | 264.8 MB/s | **1.3x** | 350.5 MB/s | 316.3 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 205.5 MB/s | 173.6 MB/s | **0.8x** | 363.8 MB/s | 238.2 MB/s | **0.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 356.8 MB/s | 421.9 MB/s | **1.2x** | 467.7 MB/s | 1564.0 MB/s | **3.3x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 350.1 MB/s | 375.6 MB/s | **1.1x** | 217.0 MB/s | 183.4 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 9 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 167.4 MB/s | 449.0 MB/s | **2.7x** | 290.2 MB/s | 1524.2 MB/s | **5.3x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 9 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 162.5 MB/s | 321.4 MB/s | **2.0x** | 195.7 MB/s | 180.3 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | TAR | 1 | 无 | 7-Zip 7zz CLI | 11.92 MB (100.8%) | 11.92 MB (100.8%) | 1331.4 MB/s | 498.1 MB/s | **0.4x** | 760.4 MB/s | 454.6 MB/s | **0.6x** | - |
| 海量小文件 (10MB/100文件) | TAR | 1 | 无 | BSD tar (Native) | 12.11 MB (102.4%) | 11.92 MB (100.8%) | 177.7 MB/s | 498.1 MB/s | **2.8x** | 206.3 MB/s | 454.6 MB/s | **2.2x** | - |
| 海量小文件 (10MB/100文件) | TAR | 9 | 无 | 7-Zip 7zz CLI | 11.92 MB (100.8%) | 11.92 MB (100.8%) | 1236.9 MB/s | 503.9 MB/s | **0.4x** | 671.7 MB/s | 470.8 MB/s | **0.7x** | - |
| 海量小文件 (10MB/100文件) | TAR | 9 | 无 | BSD tar (Native) | 12.11 MB (102.4%) | 11.92 MB (100.8%) | 184.2 MB/s | 503.9 MB/s | **2.7x** | 150.0 MB/s | 470.8 MB/s | **3.1x** | - |
| 海量小文件 (10MB/100文件) | GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.06 MB (0.5%) | 181.2 MB/s | 445.7 MB/s | **2.5x** | 180.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | GZ | 9 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.05 MB (0.5%) | 186.5 MB/s | 446.3 MB/s | **2.4x** | 183.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | BZ2 | 1 | 无 | pbzip2 (All Cores) | 0.07 MB (0.6%) | 0.06 MB (0.5%) | 67.3 MB/s | 449.2 MB/s | **6.7x** | 125.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | BZ2 | 9 | 无 | pbzip2 (All Cores) | 0.02 MB (0.1%) | 0.05 MB (0.5%) | 47.3 MB/s | 439.6 MB/s | **9.3x** | 86.6 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | XZ | 1 | 无 | pixz (Parallel XZ) | 0.01 MB (0.1%) | 0.06 MB (0.5%) | 122.4 MB/s | 445.1 MB/s | **3.6x** | 172.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | XZ | 9 | 无 | pixz (Parallel XZ) | 0.01 MB (0.0%) | 0.05 MB (0.5%) | 66.2 MB/s | 441.2 MB/s | **6.7x** | 158.7 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | LZIP | 1 | 无 | plzip (Multi-thread Lzip) | 0.01 MB (0.1%) | 0.06 MB (0.5%) | 55.9 MB/s | 442.4 MB/s | **7.9x** | 149.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | LZIP | 9 | 无 | plzip (Multi-thread Lzip) | 0.00 MB (0.0%) | 0.05 MB (0.5%) | 6.4 MB/s | 442.8 MB/s | **69.2x** | 106.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | LZ4 | 1 | 无 | official lz4 CLI | 0.10 MB (0.9%) | 0.06 MB (0.5%) | 177.8 MB/s | 453.8 MB/s | **2.6x** | 180.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | LZ4 | 9 | 无 | official lz4 CLI | 0.09 MB (0.8%) | 0.05 MB (0.5%) | 81.3 MB/s | 444.9 MB/s | **5.5x** | 172.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | BROTLI | 1 | 无 | brotli CLI | 0.02 MB (0.2%) | 0.06 MB (0.5%) | 195.4 MB/s | 450.7 MB/s | **2.3x** | 163.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | BROTLI | 9 | 无 | brotli CLI | 0.00 MB (0.0%) | 0.05 MB (0.5%) | 174.6 MB/s | 414.0 MB/s | **2.4x** | 175.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | LRZIP | 1 | 无 | lrzip (Multi-core) | 0.00 MB (0.0%) | 0.06 MB (0.5%) | 93.9 MB/s | 450.2 MB/s | **4.8x** | 116.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | LRZIP | 9 | 无 | lrzip (Multi-core) | 0.00 MB (0.0%) | 0.05 MB (0.5%) | 75.7 MB/s | 447.3 MB/s | **5.9x** | 90.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | AAR | 1 | 无 | Apple aa (AppleArchive LZFSE) | 0.01 MB (0.1%) | 0.06 MB (0.5%) | 396.2 MB/s | 451.5 MB/s | **1.1x** | 720.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | AAR | 9 | 无 | Apple aa (AppleArchive LZFSE) | 0.01 MB (0.1%) | 0.05 MB (0.5%) | 412.0 MB/s | 410.2 MB/s | **1.0x** | 276.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | WIM | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.06 MB (0.5%) | 810.3 MB/s | 400.5 MB/s | **0.5x** | 564.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | WIM | 1 | 无 | wimlib-imagex | 0.00 MB (0.0%) | 0.06 MB (0.5%) | 689.1 MB/s | 400.5 MB/s | **0.6x** | 769.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | WIM | 1 | AES-256 | wimlib-imagex | 0.00 MB (0.0%) | 0.06 MB (0.5%) | 783.5 MB/s | 360.5 MB/s | **0.5x** | 709.7 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | WIM | 9 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.05 MB (0.5%) | 213.8 MB/s | 382.5 MB/s | **1.8x** | 363.7 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | WIM | 9 | 无 | wimlib-imagex | 0.00 MB (0.0%) | 0.05 MB (0.5%) | 728.2 MB/s | 382.5 MB/s | **0.5x** | 703.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | WIM | 9 | AES-256 | wimlib-imagex | 0.00 MB (0.0%) | 0.06 MB (0.5%) | 742.9 MB/s | 345.7 MB/s | **0.5x** | 751.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | DMG | 1 | 无 | macOS hdiutil (DMG) | 0.11 MB (1.0%) | 0.06 MB (0.5%) | 2.3 MB/s | 404.6 MB/s | **172.4x** | 224.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | DMG | 1 | AES-256 | macOS hdiutil (DMG) | 0.11 MB (1.0%) | 0.06 MB (0.5%) | 2.9 MB/s | 392.3 MB/s | **133.6x** | 212.6 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | DMG | 9 | 无 | macOS hdiutil (DMG) | 0.11 MB (1.0%) | 0.05 MB (0.5%) | 2.3 MB/s | 403.5 MB/s | **171.8x** | 228.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | DMG | 9 | AES-256 | macOS hdiutil (DMG) | 0.11 MB (1.0%) | 0.06 MB (0.5%) | 2.4 MB/s | 385.6 MB/s | **164.1x** | 225.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | ISO | 1 | 无 | macOS hdiutil (ISO) | 11.99 MB (101.4%) | 0.06 MB (0.5%) | 336.6 MB/s | 448.4 MB/s | **1.3x** | 673.7 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | ISO | 9 | 无 | macOS hdiutil (ISO) | 11.99 MB (101.4%) | 0.05 MB (0.5%) | 354.0 MB/s | 446.7 MB/s | **1.3x** | 758.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1036.6 MB/s | 319.4 MB/s | **0.3x** | 1483.4 MB/s | 1167.4 MB/s | **0.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 828.0 MB/s | 213.2 MB/s | **0.3x** | 714.1 MB/s | 519.0 MB/s | **0.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 214.7 MB/s | 344.9 MB/s | **1.6x** | 901.7 MB/s | 1227.6 MB/s | **1.4x** | - |
| 拟真日志文本 (10MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 216.2 MB/s | 214.6 MB/s | **1.0x** | 534.2 MB/s | 515.1 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 532.0 MB/s | 727.9 MB/s | **1.4x** | 847.2 MB/s | 4105.0 MB/s | **4.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 519.0 MB/s | 696.0 MB/s | **1.3x** | 871.1 MB/s | 625.3 MB/s | **0.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 9 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 15.1 MB/s | 582.1 MB/s | **38.5x** | 819.6 MB/s | 4639.4 MB/s | **5.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 9 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 15.3 MB/s | 556.8 MB/s | **36.3x** | 903.7 MB/s | 634.1 MB/s | **0.7x** | - |
| 拟真日志文本 (10MB) | TAR | 1 | 无 | 7-Zip 7zz CLI | 11.16 MB (100.0%) | 11.16 MB (100.0%) | 1891.3 MB/s | 1170.5 MB/s | **0.6x** | 2083.4 MB/s | 3436.5 MB/s | **1.6x** | - |
| 拟真日志文本 (10MB) | TAR | 1 | 无 | BSD tar (Native) | 11.16 MB (100.0%) | 11.16 MB (100.0%) | 896.7 MB/s | 1170.5 MB/s | **1.3x** | 1046.4 MB/s | 3436.5 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | TAR | 9 | 无 | 7-Zip 7zz CLI | 11.16 MB (100.0%) | 11.16 MB (100.0%) | 1759.6 MB/s | 1191.9 MB/s | **0.7x** | 2047.7 MB/s | 3101.2 MB/s | **1.5x** | - |
| 拟真日志文本 (10MB) | TAR | 9 | 无 | BSD tar (Native) | 11.16 MB (100.0%) | 11.16 MB (100.0%) | 880.9 MB/s | 1191.9 MB/s | **1.4x** | 1017.4 MB/s | 3101.2 MB/s | **3.0x** | - |
| 拟真日志文本 (10MB) | ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1800.0 MB/s | 1257.1 MB/s | **0.7x** | 1773.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | ZST | 9 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 868.7 MB/s | 825.3 MB/s | **0.9x** | 1717.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 947.5 MB/s | 712.7 MB/s | **0.8x** | 769.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | GZ | 9 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 1113.0 MB/s | 584.3 MB/s | **0.5x** | 764.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | BZ2 | 1 | 无 | pbzip2 (All Cores) | 0.04 MB (0.3%) | 0.04 MB (0.4%) | 90.7 MB/s | 726.5 MB/s | **8.0x** | 143.6 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | BZ2 | 9 | 无 | pbzip2 (All Cores) | 0.01 MB (0.1%) | 0.04 MB (0.3%) | 65.2 MB/s | 577.6 MB/s | **8.9x** | 126.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | XZ | 1 | 无 | pixz (Parallel XZ) | 0.00 MB (0.0%) | 0.04 MB (0.4%) | 431.6 MB/s | 720.6 MB/s | **1.7x** | 535.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | XZ | 9 | 无 | pixz (Parallel XZ) | 0.00 MB (0.0%) | 0.04 MB (0.3%) | 103.7 MB/s | 576.5 MB/s | **5.6x** | 389.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | LZIP | 1 | 无 | plzip (Multi-thread Lzip) | 0.00 MB (0.0%) | 0.04 MB (0.4%) | 225.9 MB/s | 674.5 MB/s | **3.0x** | 349.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | LZIP | 9 | 无 | plzip (Multi-thread Lzip) | 0.00 MB (0.0%) | 0.04 MB (0.3%) | 7.2 MB/s | 577.7 MB/s | **80.3x** | 180.6 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | LZ4 | 1 | 无 | official lz4 CLI | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 615.7 MB/s | 731.2 MB/s | **1.2x** | 613.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | LZ4 | 9 | 无 | official lz4 CLI | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 610.7 MB/s | 573.6 MB/s | **0.9x** | 639.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | BROTLI | 1 | 无 | brotli CLI | 0.01 MB (0.1%) | 0.04 MB (0.4%) | 747.1 MB/s | 723.6 MB/s | **1.0x** | 479.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | BROTLI | 9 | 无 | brotli CLI | 0.00 MB (0.0%) | 0.04 MB (0.3%) | 428.9 MB/s | 569.9 MB/s | **1.3x** | 493.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | LRZIP | 1 | 无 | lrzip (Multi-core) | 0.00 MB (0.0%) | 0.04 MB (0.4%) | 213.4 MB/s | 725.4 MB/s | **3.4x** | 226.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | LRZIP | 9 | 无 | lrzip (Multi-core) | 0.00 MB (0.0%) | 0.04 MB (0.3%) | 172.1 MB/s | 581.0 MB/s | **3.4x** | 229.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | WIM | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.04 MB (0.4%) | 1053.6 MB/s | 671.5 MB/s | **0.6x** | 1509.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | WIM | 9 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.04 MB (0.3%) | 219.3 MB/s | 575.8 MB/s | **2.6x** | 890.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | DMG | 1 | 无 | macOS hdiutil (DMG) | 0.10 MB (0.9%) | 0.04 MB (0.4%) | 2.2 MB/s | 720.7 MB/s | **325.1x** | 376.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | DMG | 1 | AES-256 | macOS hdiutil (DMG) | 0.10 MB (0.9%) | 0.04 MB (0.4%) | 2.2 MB/s | 679.4 MB/s | **306.6x** | 351.7 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | DMG | 9 | 无 | macOS hdiutil (DMG) | 0.10 MB (0.9%) | 0.04 MB (0.3%) | 2.2 MB/s | 572.9 MB/s | **258.5x** | 386.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | DMG | 9 | AES-256 | macOS hdiutil (DMG) | 0.10 MB (0.9%) | 0.04 MB (0.3%) | 2.2 MB/s | 558.0 MB/s | **251.8x** | 571.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 99.7 MB/s | 1787.8 MB/s | **17.9x** | 2516.7 MB/s | 4458.5 MB/s | **1.8x** | 2_SolidBuf_IO_and_CRC32 (97.0%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 82.8 MB/s | 152.3 MB/s | **1.8x** | 2011.7 MB/s | 999.8 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 108.1 MB/s | 1801.1 MB/s | **16.7x** | 1166.0 MB/s | 3930.9 MB/s | **3.4x** | 2_SolidBuf_IO_and_CRC32 (97.2%) |
| 高熵物理Payload (100MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 111.2 MB/s | 108.9 MB/s | **1.0x** | 1041.8 MB/s | 1037.6 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 60.5 MB/s | 1322.3 MB/s | **21.8x** | 2891.3 MB/s | 7281.7 MB/s | **2.5x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 53.7 MB/s | 634.9 MB/s | **11.8x** | 1226.0 MB/s | 608.9 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | ZIP | 9 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 3.2 MB/s | 1320.9 MB/s | **410.1x** | 2613.6 MB/s | 7698.4 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 9 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 3.1 MB/s | 735.9 MB/s | **237.7x** | 1258.5 MB/s | 616.9 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | TAR | 1 | 无 | 7-Zip 7zz CLI | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4548.6 MB/s | 1301.3 MB/s | **0.3x** | 4764.0 MB/s | 4322.8 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | TAR | 1 | 无 | BSD tar (Native) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 1609.9 MB/s | 1301.3 MB/s | **0.8x** | 1563.1 MB/s | 4322.8 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | TAR | 9 | 无 | 7-Zip 7zz CLI | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4561.7 MB/s | 1261.8 MB/s | **0.3x** | 4791.0 MB/s | 4524.1 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | TAR | 9 | 无 | BSD tar (Native) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 1603.5 MB/s | 1261.8 MB/s | **0.8x** | 1591.7 MB/s | 4524.1 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5099.0 MB/s | 860.6 MB/s | **0.2x** | 5823.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | ZST | 9 | 无 | Zstandard zstd (Thread=0) | 1.01 MB (1.0%) | 1.01 MB (1.0%) | 3432.9 MB/s | 892.5 MB/s | **0.3x** | 6215.7 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.00 MB (100.0%) | 322.6 MB/s | 1317.5 MB/s | **4.1x** | 1057.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | GZ | 9 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.00 MB (100.0%) | 485.2 MB/s | 1336.9 MB/s | **2.8x** | 1037.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | BZ2 | 1 | 无 | pbzip2 (All Cores) | 100.81 MB (100.8%) | 100.00 MB (100.0%) | 111.4 MB/s | 1337.4 MB/s | **12.0x** | 253.7 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | BZ2 | 9 | 无 | pbzip2 (All Cores) | 100.45 MB (100.5%) | 100.00 MB (100.0%) | 96.9 MB/s | 1333.9 MB/s | **13.8x** | 159.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | XZ | 1 | 无 | pixz (Parallel XZ) | 50.03 MB (50.0%) | 100.00 MB (100.0%) | 94.4 MB/s | 1277.6 MB/s | **13.5x** | 809.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | XZ | 9 | 无 | pixz (Parallel XZ) | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 35.1 MB/s | 1308.5 MB/s | **37.3x** | 788.6 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | LZIP | 1 | 无 | plzip (Multi-thread Lzip) | 50.70 MB (50.7%) | 100.00 MB (100.0%) | 71.7 MB/s | 1343.7 MB/s | **18.7x** | 217.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | LZIP | 9 | 无 | plzip (Multi-thread Lzip) | 2.04 MB (2.0%) | 100.00 MB (100.0%) | 6.4 MB/s | 1339.6 MB/s | **208.3x** | 323.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | LZ4 | 1 | 无 | official lz4 CLI | 100.39 MB (100.4%) | 100.00 MB (100.0%) | 2315.1 MB/s | 1334.1 MB/s | **0.6x** | 1191.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | LZ4 | 9 | 无 | official lz4 CLI | 100.39 MB (100.4%) | 100.00 MB (100.0%) | 528.1 MB/s | 1338.4 MB/s | **2.5x** | 1188.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | BROTLI | 1 | 无 | brotli CLI | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 1697.7 MB/s | 1383.7 MB/s | **0.8x** | 1084.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | BROTLI | 9 | 无 | brotli CLI | 1.00 MB (1.0%) | 100.00 MB (100.0%) | 677.8 MB/s | 1307.5 MB/s | **1.9x** | 640.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | LRZIP | 1 | 无 | lrzip (Multi-core) | 1.01 MB (1.0%) | 100.00 MB (100.0%) | 219.6 MB/s | 1325.8 MB/s | **6.0x** | 266.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | LRZIP | 9 | 无 | lrzip (Multi-core) | 1.01 MB (1.0%) | 100.00 MB (100.0%) | 212.0 MB/s | 1360.4 MB/s | **6.4x** | 269.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | WIM | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 195.7 MB/s | 1329.8 MB/s | **6.8x** | 3350.7 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | WIM | 9 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 151.8 MB/s | 1302.1 MB/s | **8.6x** | 1154.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | DMG | 1 | 无 | macOS hdiutil (DMG) | 101.96 MB (102.0%) | 100.00 MB (100.0%) | 16.6 MB/s | 1316.1 MB/s | **79.4x** | 1886.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | DMG | 1 | AES-256 | macOS hdiutil (DMG) | 101.96 MB (102.0%) | 100.00 MB (100.0%) | 14.2 MB/s | 739.6 MB/s | **52.1x** | 2207.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | DMG | 9 | 无 | macOS hdiutil (DMG) | 101.96 MB (102.0%) | 100.00 MB (100.0%) | 14.2 MB/s | 1311.3 MB/s | **92.3x** | 2040.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | DMG | 9 | AES-256 | macOS hdiutil (DMG) | 101.96 MB (102.0%) | 100.00 MB (100.0%) | 16.6 MB/s | 744.9 MB/s | **45.0x** | 1989.7 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 4973.5 MB/s | 2033.9 MB/s | **0.4x** | 4136.0 MB/s | 1341.6 MB/s | **0.3x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4958.5 MB/s | 451.6 MB/s | **0.1x** | 3800.4 MB/s | 2569.9 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 401.4 MB/s | 2616.5 MB/s | **6.5x** | 2673.8 MB/s | 1233.8 MB/s | **0.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 253.7 MB/s | 249.3 MB/s | **1.0x** | 2193.9 MB/s | 1471.0 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 682.8 MB/s | 377.4 MB/s | **0.6x** | 1180.0 MB/s | 4900.9 MB/s | **4.2x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 681.7 MB/s | 431.8 MB/s | **0.6x** | 1412.5 MB/s | 606.2 MB/s | **0.4x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 9 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 16.6 MB/s | 329.3 MB/s | **19.8x** | 1168.9 MB/s | 9165.4 MB/s | **7.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 9 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 16.8 MB/s | 329.8 MB/s | **19.7x** | 1357.7 MB/s | 1059.7 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR | 1 | 无 | 7-Zip 7zz CLI | 500.00 MB (100.0%) | 500.00 MB (100.0%) | 6057.2 MB/s | 1264.7 MB/s | **0.2x** | 5709.9 MB/s | 4481.6 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR | 1 | 无 | BSD tar (Native) | 500.00 MB (100.0%) | 500.00 MB (100.0%) | 1725.6 MB/s | 1264.7 MB/s | **0.7x** | 1592.4 MB/s | 4481.6 MB/s | **2.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR | 9 | 无 | 7-Zip 7zz CLI | 500.00 MB (100.0%) | 500.00 MB (100.0%) | 5801.9 MB/s | 1308.0 MB/s | **0.2x** | 5574.3 MB/s | 5068.8 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR | 9 | 无 | BSD tar (Native) | 500.00 MB (100.0%) | 500.00 MB (100.0%) | 1688.6 MB/s | 1308.0 MB/s | **0.8x** | 1573.7 MB/s | 5068.8 MB/s | **3.2x** | - |
| 500MB 大文件数据块 (500MB) | ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 11175.2 MB/s | 1266.7 MB/s | **0.1x** | 4333.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | ZST | 9 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 6766.0 MB/s | 669.5 MB/s | **0.1x** | 4226.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.58 MB (0.1%) | 3880.4 MB/s | 377.0 MB/s | **0.1x** | 1649.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | GZ | 9 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.51 MB (0.1%) | 4590.2 MB/s | 333.4 MB/s | **0.1x** | 1702.6 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | BZ2 | 1 | 无 | pbzip2 (All Cores) | 0.03 MB (0.0%) | 0.58 MB (0.1%) | 1116.7 MB/s | 379.3 MB/s | **0.3x** | 1300.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | BZ2 | 9 | 无 | pbzip2 (All Cores) | 0.03 MB (0.0%) | 0.51 MB (0.1%) | 2212.1 MB/s | 332.7 MB/s | **0.2x** | 1350.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | XZ | 1 | 无 | pixz (Parallel XZ) | 0.10 MB (0.0%) | 0.58 MB (0.1%) | 3114.1 MB/s | 380.4 MB/s | **0.1x** | 1246.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | XZ | 9 | 无 | pixz (Parallel XZ) | 0.07 MB (0.0%) | 0.51 MB (0.1%) | 448.4 MB/s | 329.0 MB/s | **0.7x** | 991.7 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | LZIP | 1 | 无 | plzip (Multi-thread Lzip) | 0.10 MB (0.0%) | 0.58 MB (0.1%) | 1314.2 MB/s | 380.4 MB/s | **0.3x** | 1229.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | LZIP | 9 | 无 | plzip (Multi-thread Lzip) | 0.07 MB (0.0%) | 0.51 MB (0.1%) | 49.1 MB/s | 330.5 MB/s | **6.7x** | 888.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | LZ4 | 1 | 无 | official lz4 CLI | 1.96 MB (0.4%) | 0.58 MB (0.1%) | 3209.6 MB/s | 379.0 MB/s | **0.1x** | 1237.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | LZ4 | 9 | 无 | official lz4 CLI | 1.96 MB (0.4%) | 0.51 MB (0.1%) | 3066.3 MB/s | 329.7 MB/s | **0.1x** | 1282.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | BROTLI | 1 | 无 | brotli CLI | 0.09 MB (0.0%) | 0.58 MB (0.1%) | 2820.4 MB/s | 374.4 MB/s | **0.1x** | 1090.6 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | BROTLI | 9 | 无 | brotli CLI | 0.00 MB (0.0%) | 0.51 MB (0.1%) | 668.0 MB/s | 326.0 MB/s | **0.5x** | 782.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | LRZIP | 1 | 无 | lrzip (Multi-core) | 0.07 MB (0.0%) | 0.58 MB (0.1%) | 146.4 MB/s | 375.0 MB/s | **2.6x** | 267.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | LRZIP | 9 | 无 | lrzip (Multi-core) | 0.07 MB (0.0%) | 0.51 MB (0.1%) | 99.4 MB/s | 332.7 MB/s | **3.3x** | 269.7 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | WIM | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.58 MB (0.1%) | 3089.2 MB/s | 375.8 MB/s | **0.1x** | 3510.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | WIM | 9 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.51 MB (0.1%) | 453.0 MB/s | 334.1 MB/s | **0.7x** | 2664.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | DMG | 1 | 无 | macOS hdiutil (DMG) | 0.06 MB (0.0%) | 0.58 MB (0.1%) | 82.4 MB/s | 372.7 MB/s | **4.5x** | 6435.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | DMG | 1 | AES-256 | macOS hdiutil (DMG) | 0.06 MB (0.0%) | 0.58 MB (0.1%) | 82.4 MB/s | 379.2 MB/s | **4.6x** | 6451.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | DMG | 9 | 无 | macOS hdiutil (DMG) | 0.06 MB (0.0%) | 0.51 MB (0.1%) | 98.9 MB/s | 396.7 MB/s | **4.0x** | 6482.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | DMG | 9 | AES-256 | macOS hdiutil (DMG) | 0.06 MB (0.0%) | 0.51 MB (0.1%) | 98.9 MB/s | 333.8 MB/s | **3.4x** | 7225.1 MB/s | 0.0 MB/s | **0.0x** | - |
