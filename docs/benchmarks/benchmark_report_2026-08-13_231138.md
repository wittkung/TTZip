# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-13 15:11:38 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS Version 26.6 (Build 25G72)
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 801.0 MB/s | 255.5 MB/s | **0.3x** | 627.7 MB/s | 408.0 MB/s | **0.6x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 792.3 MB/s | 178.2 MB/s | **0.2x** | 446.0 MB/s | 357.0 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 210.0 MB/s | 292.2 MB/s | **1.4x** | 506.5 MB/s | 456.3 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 207.5 MB/s | 175.8 MB/s | **0.8x** | 312.6 MB/s | 357.3 MB/s | **1.1x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 370.0 MB/s | 420.5 MB/s | **1.1x** | 455.8 MB/s | 1436.8 MB/s | **3.2x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 358.8 MB/s | 382.4 MB/s | **1.1x** | 189.0 MB/s | 181.1 MB/s | **1.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 9 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 176.2 MB/s | 445.7 MB/s | **2.5x** | 480.0 MB/s | 1454.2 MB/s | **3.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 9 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 171.3 MB/s | 382.7 MB/s | **2.2x** | 213.5 MB/s | 186.6 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | TAR | 1 | 无 | 7-Zip 7zz CLI | 11.92 MB (100.8%) | 11.92 MB (100.8%) | 1295.5 MB/s | 497.8 MB/s | **0.4x** | 746.0 MB/s | 644.4 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | TAR | 1 | 无 | BSD tar (Native) | 12.11 MB (102.4%) | 11.92 MB (100.8%) | 213.2 MB/s | 497.8 MB/s | **2.3x** | 208.0 MB/s | 644.4 MB/s | **3.1x** | - |
| 海量小文件 (10MB/100文件) | TAR | 9 | 无 | 7-Zip 7zz CLI | 11.92 MB (100.8%) | 11.92 MB (100.8%) | 1316.8 MB/s | 516.1 MB/s | **0.4x** | 750.4 MB/s | 674.7 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | TAR | 9 | 无 | BSD tar (Native) | 12.11 MB (102.4%) | 11.92 MB (100.8%) | 228.3 MB/s | 516.1 MB/s | **2.3x** | 213.8 MB/s | 674.7 MB/s | **3.2x** | - |
| 海量小文件 (10MB/100文件) | GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.06 MB (0.5%) | 201.4 MB/s | 451.0 MB/s | **2.2x** | 185.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | GZ | 9 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.05 MB (0.5%) | 201.7 MB/s | 422.4 MB/s | **2.1x** | 191.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | BZ2 | 1 | 无 | pbzip2 (All Cores) | 0.07 MB (0.6%) | 0.06 MB (0.5%) | 73.0 MB/s | 453.4 MB/s | **6.2x** | 127.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | BZ2 | 9 | 无 | pbzip2 (All Cores) | 0.02 MB (0.1%) | 0.05 MB (0.5%) | 45.8 MB/s | 448.2 MB/s | **9.8x** | 63.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | XZ | 1 | 无 | pixz (Parallel XZ) | 0.01 MB (0.1%) | 0.06 MB (0.5%) | 173.9 MB/s | 454.1 MB/s | **2.6x** | 178.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | XZ | 9 | 无 | pixz (Parallel XZ) | 0.01 MB (0.0%) | 0.05 MB (0.5%) | 69.9 MB/s | 443.3 MB/s | **6.3x** | 167.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | LZIP | 1 | 无 | plzip (Multi-thread Lzip) | 0.01 MB (0.1%) | 0.06 MB (0.5%) | 135.0 MB/s | 449.6 MB/s | **3.3x** | 159.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | LZIP | 9 | 无 | plzip (Multi-thread Lzip) | 0.00 MB (0.0%) | 0.05 MB (0.5%) | 6.4 MB/s | 452.5 MB/s | **70.8x** | 101.6 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | LZ4 | 1 | 无 | official lz4 CLI | 0.10 MB (0.9%) | 0.06 MB (0.5%) | 187.9 MB/s | 406.7 MB/s | **2.2x** | 164.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | LZ4 | 9 | 无 | official lz4 CLI | 0.09 MB (0.8%) | 0.05 MB (0.5%) | 72.6 MB/s | 399.8 MB/s | **5.5x** | 160.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | BROTLI | 1 | 无 | brotli CLI | 0.02 MB (0.2%) | 0.06 MB (0.5%) | 208.2 MB/s | 449.1 MB/s | **2.2x** | 175.6 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | BROTLI | 9 | 无 | brotli CLI | 0.00 MB (0.0%) | 0.05 MB (0.5%) | 168.4 MB/s | 427.8 MB/s | **2.5x** | 173.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | LRZIP | 1 | 无 | lrzip (Multi-core) | 0.00 MB (0.0%) | 0.06 MB (0.5%) | 107.0 MB/s | 464.3 MB/s | **4.3x** | 120.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | LRZIP | 9 | 无 | lrzip (Multi-core) | 0.00 MB (0.0%) | 0.05 MB (0.5%) | 77.6 MB/s | 450.0 MB/s | **5.8x** | 114.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | AAR | 1 | 无 | Apple aa (AppleArchive LZFSE) | 0.01 MB (0.1%) | 0.06 MB (0.5%) | 404.5 MB/s | 359.1 MB/s | **0.9x** | 781.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | AAR | 9 | 无 | Apple aa (AppleArchive LZFSE) | 0.01 MB (0.1%) | 0.05 MB (0.5%) | 416.4 MB/s | 448.9 MB/s | **1.1x** | 821.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | WIM | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.06 MB (0.5%) | 807.9 MB/s | 460.6 MB/s | **0.6x** | 596.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | WIM | 1 | 无 | wimlib-imagex | 0.00 MB (0.0%) | 0.06 MB (0.5%) | 728.6 MB/s | 460.6 MB/s | **0.6x** | 817.6 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | WIM | 1 | AES-256 | wimlib-imagex | 0.00 MB (0.0%) | 0.06 MB (0.5%) | 739.6 MB/s | 393.2 MB/s | **0.5x** | 796.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | WIM | 9 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.05 MB (0.5%) | 218.5 MB/s | 449.7 MB/s | **2.1x** | 497.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | WIM | 9 | 无 | wimlib-imagex | 0.00 MB (0.0%) | 0.05 MB (0.5%) | 757.2 MB/s | 449.7 MB/s | **0.6x** | 726.6 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | WIM | 9 | AES-256 | wimlib-imagex | 0.00 MB (0.0%) | 0.06 MB (0.5%) | 750.9 MB/s | 370.8 MB/s | **0.5x** | 862.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | DMG | 1 | 无 | macOS hdiutil (DMG) | 0.11 MB (1.0%) | 0.06 MB (0.5%) | 2.3 MB/s | 265.5 MB/s | **113.0x** | 272.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | DMG | 1 | AES-256 | macOS hdiutil (DMG) | 0.11 MB (1.0%) | 0.06 MB (0.5%) | 2.3 MB/s | 381.5 MB/s | **162.3x** | 272.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | DMG | 9 | 无 | macOS hdiutil (DMG) | 0.11 MB (1.0%) | 0.05 MB (0.5%) | 2.4 MB/s | 420.2 MB/s | **178.7x** | 274.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | DMG | 9 | AES-256 | macOS hdiutil (DMG) | 0.11 MB (1.0%) | 0.06 MB (0.5%) | 2.4 MB/s | 378.6 MB/s | **161.1x** | 291.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | ISO | 1 | 无 | macOS hdiutil (ISO) | 11.99 MB (101.4%) | 0.06 MB (0.5%) | 356.4 MB/s | 447.5 MB/s | **1.3x** | 686.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | ISO | 9 | 无 | macOS hdiutil (ISO) | 11.99 MB (101.4%) | 0.05 MB (0.5%) | 347.0 MB/s | 424.3 MB/s | **1.2x** | 763.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1066.8 MB/s | 324.9 MB/s | **0.3x** | 1494.9 MB/s | 1198.6 MB/s | **0.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 822.4 MB/s | 216.5 MB/s | **0.3x** | 712.0 MB/s | 512.9 MB/s | **0.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 222.4 MB/s | 352.0 MB/s | **1.6x** | 891.5 MB/s | 1267.9 MB/s | **1.4x** | - |
| 拟真日志文本 (10MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 218.7 MB/s | 216.7 MB/s | **1.0x** | 537.8 MB/s | 525.7 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 535.9 MB/s | 724.6 MB/s | **1.4x** | 854.0 MB/s | 4047.5 MB/s | **4.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 519.0 MB/s | 697.2 MB/s | **1.3x** | 899.8 MB/s | 617.8 MB/s | **0.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 9 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 15.0 MB/s | 580.5 MB/s | **38.8x** | 859.0 MB/s | 4673.3 MB/s | **5.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 9 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 15.4 MB/s | 572.8 MB/s | **37.2x** | 902.5 MB/s | 712.6 MB/s | **0.8x** | - |
| 拟真日志文本 (10MB) | TAR | 1 | 无 | 7-Zip 7zz CLI | 11.16 MB (100.0%) | 11.16 MB (100.0%) | 1965.1 MB/s | 1143.5 MB/s | **0.6x** | 2074.6 MB/s | 3471.9 MB/s | **1.7x** | - |
| 拟真日志文本 (10MB) | TAR | 1 | 无 | BSD tar (Native) | 11.16 MB (100.0%) | 11.16 MB (100.0%) | 896.3 MB/s | 1143.5 MB/s | **1.3x** | 1047.0 MB/s | 3471.9 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | TAR | 9 | 无 | 7-Zip 7zz CLI | 11.16 MB (100.0%) | 11.16 MB (100.0%) | 2024.9 MB/s | 1165.4 MB/s | **0.6x** | 2126.4 MB/s | 3613.8 MB/s | **1.7x** | - |
| 拟真日志文本 (10MB) | TAR | 9 | 无 | BSD tar (Native) | 11.16 MB (100.0%) | 11.16 MB (100.0%) | 846.2 MB/s | 1165.4 MB/s | **1.4x** | 1028.6 MB/s | 3613.8 MB/s | **3.5x** | - |
| 拟真日志文本 (10MB) | ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 2088.2 MB/s | 1253.4 MB/s | **0.6x** | 1701.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | ZST | 9 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 879.3 MB/s | 797.0 MB/s | **0.9x** | 1694.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 953.8 MB/s | 726.4 MB/s | **0.8x** | 719.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | GZ | 9 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 1094.3 MB/s | 578.2 MB/s | **0.5x** | 714.6 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | BZ2 | 1 | 无 | pbzip2 (All Cores) | 0.04 MB (0.3%) | 0.04 MB (0.4%) | 84.2 MB/s | 715.6 MB/s | **8.5x** | 152.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | BZ2 | 9 | 无 | pbzip2 (All Cores) | 0.01 MB (0.1%) | 0.04 MB (0.3%) | 64.5 MB/s | 578.3 MB/s | **9.0x** | 118.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | XZ | 1 | 无 | pixz (Parallel XZ) | 0.00 MB (0.0%) | 0.04 MB (0.4%) | 415.2 MB/s | 712.8 MB/s | **1.7x** | 509.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | XZ | 9 | 无 | pixz (Parallel XZ) | 0.00 MB (0.0%) | 0.04 MB (0.3%) | 100.3 MB/s | 573.2 MB/s | **5.7x** | 383.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | LZIP | 1 | 无 | plzip (Multi-thread Lzip) | 0.00 MB (0.0%) | 0.04 MB (0.4%) | 242.9 MB/s | 716.6 MB/s | **3.0x** | 352.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | LZIP | 9 | 无 | plzip (Multi-thread Lzip) | 0.00 MB (0.0%) | 0.04 MB (0.3%) | 7.1 MB/s | 574.6 MB/s | **80.6x** | 176.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | LZ4 | 1 | 无 | official lz4 CLI | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 701.7 MB/s | 706.6 MB/s | **1.0x** | 615.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | LZ4 | 9 | 无 | official lz4 CLI | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 598.7 MB/s | 575.8 MB/s | **1.0x** | 614.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | BROTLI | 1 | 无 | brotli CLI | 0.01 MB (0.1%) | 0.04 MB (0.4%) | 707.5 MB/s | 709.0 MB/s | **1.0x** | 466.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | BROTLI | 9 | 无 | brotli CLI | 0.00 MB (0.0%) | 0.04 MB (0.3%) | 414.1 MB/s | 576.6 MB/s | **1.4x** | 465.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | LRZIP | 1 | 无 | lrzip (Multi-core) | 0.00 MB (0.0%) | 0.04 MB (0.4%) | 212.3 MB/s | 713.5 MB/s | **3.4x** | 160.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | LRZIP | 9 | 无 | lrzip (Multi-core) | 0.00 MB (0.0%) | 0.04 MB (0.3%) | 158.3 MB/s | 557.7 MB/s | **3.5x** | 212.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | WIM | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.04 MB (0.4%) | 1067.1 MB/s | 668.9 MB/s | **0.6x** | 1348.6 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | WIM | 9 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.04 MB (0.3%) | 219.2 MB/s | 568.7 MB/s | **2.6x** | 887.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | DMG | 1 | 无 | macOS hdiutil (DMG) | 0.10 MB (0.9%) | 0.04 MB (0.4%) | 2.8 MB/s | 719.2 MB/s | **259.7x** | 434.6 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | DMG | 1 | AES-256 | macOS hdiutil (DMG) | 0.10 MB (0.9%) | 0.04 MB (0.4%) | 2.8 MB/s | 691.9 MB/s | **249.7x** | 489.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | DMG | 9 | 无 | macOS hdiutil (DMG) | 0.10 MB (0.9%) | 0.04 MB (0.3%) | 2.2 MB/s | 572.5 MB/s | **258.2x** | 429.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | DMG | 9 | AES-256 | macOS hdiutil (DMG) | 0.10 MB (0.9%) | 0.04 MB (0.3%) | 2.8 MB/s | 562.2 MB/s | **202.9x** | 440.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 98.6 MB/s | 1781.9 MB/s | **18.1x** | 2829.6 MB/s | 4590.4 MB/s | **1.6x** | 2_SolidBuf_IO_and_CRC32 (97.1%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 96.2 MB/s | 153.8 MB/s | **1.6x** | 1992.0 MB/s | 1066.0 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 90.9 MB/s | 1777.1 MB/s | **19.6x** | 986.9 MB/s | 4589.1 MB/s | **4.7x** | 2_SolidBuf_IO_and_CRC32 (97.2%) |
| 高熵物理Payload (100MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 106.2 MB/s | 106.3 MB/s | **1.0x** | 1055.8 MB/s | 1044.9 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 59.9 MB/s | 1317.7 MB/s | **22.0x** | 2775.7 MB/s | 7381.3 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 55.0 MB/s | 612.8 MB/s | **11.1x** | 1267.1 MB/s | 624.0 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | ZIP | 9 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 3.0 MB/s | 1313.2 MB/s | **441.1x** | 2745.6 MB/s | 7416.0 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 9 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 3.2 MB/s | 726.9 MB/s | **227.4x** | 1269.2 MB/s | 614.9 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | TAR | 1 | 无 | 7-Zip 7zz CLI | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4191.0 MB/s | 1111.6 MB/s | **0.3x** | 4671.1 MB/s | 4317.0 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | TAR | 1 | 无 | BSD tar (Native) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 1268.5 MB/s | 1111.6 MB/s | **0.9x** | 1310.6 MB/s | 4317.0 MB/s | **3.3x** | - |
| 高熵物理Payload (100MB) | TAR | 9 | 无 | 7-Zip 7zz CLI | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5053.9 MB/s | 1306.5 MB/s | **0.3x** | 5331.9 MB/s | 4781.7 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | TAR | 9 | 无 | BSD tar (Native) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 1592.2 MB/s | 1306.5 MB/s | **0.8x** | 1465.0 MB/s | 4781.7 MB/s | **3.3x** | - |
| 高熵物理Payload (100MB) | ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5320.5 MB/s | 807.9 MB/s | **0.2x** | 5325.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | ZST | 9 | 无 | Zstandard zstd (Thread=0) | 1.01 MB (1.0%) | 1.01 MB (1.0%) | 3494.6 MB/s | 849.6 MB/s | **0.2x** | 6030.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.00 MB (100.0%) | 791.2 MB/s | 1283.1 MB/s | **1.6x** | 942.6 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | GZ | 9 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.00 MB (100.0%) | 692.8 MB/s | 1290.8 MB/s | **1.9x** | 1091.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | BZ2 | 1 | 无 | pbzip2 (All Cores) | 100.81 MB (100.8%) | 100.00 MB (100.0%) | 102.1 MB/s | 1289.2 MB/s | **12.6x** | 226.7 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | BZ2 | 9 | 无 | pbzip2 (All Cores) | 100.45 MB (100.5%) | 100.00 MB (100.0%) | 72.0 MB/s | 1232.3 MB/s | **17.1x** | 134.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | XZ | 1 | 无 | pixz (Parallel XZ) | 50.03 MB (50.0%) | 100.00 MB (100.0%) | 85.3 MB/s | 1180.5 MB/s | **13.8x** | 1088.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | XZ | 9 | 无 | pixz (Parallel XZ) | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 34.2 MB/s | 1263.1 MB/s | **36.9x** | 669.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | LZIP | 1 | 无 | plzip (Multi-thread Lzip) | 50.70 MB (50.7%) | 100.00 MB (100.0%) | 73.8 MB/s | 1287.1 MB/s | **17.4x** | 213.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | LZIP | 9 | 无 | plzip (Multi-thread Lzip) | 2.04 MB (2.0%) | 100.00 MB (100.0%) | 6.5 MB/s | 1254.5 MB/s | **193.6x** | 320.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | LZ4 | 1 | 无 | official lz4 CLI | 100.39 MB (100.4%) | 100.00 MB (100.0%) | 2291.0 MB/s | 1310.3 MB/s | **0.6x** | 1164.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | LZ4 | 9 | 无 | official lz4 CLI | 100.39 MB (100.4%) | 100.00 MB (100.0%) | 536.2 MB/s | 1324.7 MB/s | **2.5x** | 1185.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | BROTLI | 1 | 无 | brotli CLI | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 1698.4 MB/s | 1360.7 MB/s | **0.8x** | 1108.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | BROTLI | 9 | 无 | brotli CLI | 1.00 MB (1.0%) | 100.00 MB (100.0%) | 689.0 MB/s | 1328.8 MB/s | **1.9x** | 629.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | LRZIP | 1 | 无 | lrzip (Multi-core) | 1.01 MB (1.0%) | 100.00 MB (100.0%) | 216.4 MB/s | 1317.4 MB/s | **6.1x** | 266.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | LRZIP | 9 | 无 | lrzip (Multi-core) | 1.01 MB (1.0%) | 100.00 MB (100.0%) | 210.9 MB/s | 1384.1 MB/s | **6.6x** | 270.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | WIM | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 94.8 MB/s | 1310.5 MB/s | **13.8x** | 2515.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | WIM | 9 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 154.6 MB/s | 1326.2 MB/s | **8.6x** | 1201.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | DMG | 1 | 无 | macOS hdiutil (DMG) | 101.96 MB (102.0%) | 100.00 MB (100.0%) | 16.6 MB/s | 1317.9 MB/s | **79.5x** | 2012.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | DMG | 1 | AES-256 | macOS hdiutil (DMG) | 101.96 MB (102.0%) | 100.00 MB (100.0%) | 14.2 MB/s | 757.0 MB/s | **53.3x** | 2098.7 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | DMG | 9 | 无 | macOS hdiutil (DMG) | 101.96 MB (102.0%) | 100.00 MB (100.0%) | 14.2 MB/s | 1298.0 MB/s | **91.3x** | 2311.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 高熵物理Payload (100MB) | DMG | 9 | AES-256 | macOS hdiutil (DMG) | 101.96 MB (102.0%) | 100.00 MB (100.0%) | 16.6 MB/s | 747.1 MB/s | **45.1x** | 2315.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 4938.7 MB/s | 1870.6 MB/s | **0.4x** | 4104.1 MB/s | 1358.4 MB/s | **0.3x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4865.5 MB/s | 451.1 MB/s | **0.1x** | 3775.7 MB/s | 2500.0 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 472.2 MB/s | 2631.6 MB/s | **5.6x** | 2691.7 MB/s | 1359.2 MB/s | **0.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 456.9 MB/s | 455.0 MB/s | **1.0x** | 2604.9 MB/s | 2476.7 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 684.4 MB/s | 375.4 MB/s | **0.5x** | 1189.4 MB/s | 4706.3 MB/s | **4.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 683.7 MB/s | 371.9 MB/s | **0.5x** | 1351.7 MB/s | 988.6 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 9 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 16.9 MB/s | 327.4 MB/s | **19.4x** | 808.8 MB/s | 7919.5 MB/s | **9.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 9 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 16.2 MB/s | 337.6 MB/s | **20.8x** | 1398.0 MB/s | 885.2 MB/s | **0.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR | 1 | 无 | 7-Zip 7zz CLI | 500.00 MB (100.0%) | 500.00 MB (100.0%) | 5624.4 MB/s | 1312.9 MB/s | **0.2x** | 5799.2 MB/s | 4584.6 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR | 1 | 无 | BSD tar (Native) | 500.00 MB (100.0%) | 500.00 MB (100.0%) | 1640.1 MB/s | 1312.9 MB/s | **0.8x** | 1521.6 MB/s | 4584.6 MB/s | **3.0x** | - |
| 500MB 大文件数据块 (500MB) | TAR | 9 | 无 | 7-Zip 7zz CLI | 500.00 MB (100.0%) | 500.00 MB (100.0%) | 5645.6 MB/s | 1298.5 MB/s | **0.2x** | 5900.7 MB/s | 4846.2 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR | 9 | 无 | BSD tar (Native) | 500.00 MB (100.0%) | 500.00 MB (100.0%) | 1614.4 MB/s | 1298.5 MB/s | **0.8x** | 1346.5 MB/s | 4846.2 MB/s | **3.6x** | - |
| 500MB 大文件数据块 (500MB) | ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 11261.8 MB/s | 1259.6 MB/s | **0.1x** | 4338.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | ZST | 9 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 6536.8 MB/s | 710.2 MB/s | **0.1x** | 4639.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.58 MB (0.1%) | 4425.6 MB/s | 373.8 MB/s | **0.1x** | 956.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | GZ | 9 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.51 MB (0.1%) | 4168.1 MB/s | 320.1 MB/s | **0.1x** | 1788.7 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | BZ2 | 1 | 无 | pbzip2 (All Cores) | 0.03 MB (0.0%) | 0.58 MB (0.1%) | 1500.6 MB/s | 374.1 MB/s | **0.2x** | 1135.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | BZ2 | 9 | 无 | pbzip2 (All Cores) | 0.03 MB (0.0%) | 0.51 MB (0.1%) | 2215.6 MB/s | 328.3 MB/s | **0.1x** | 1260.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | XZ | 1 | 无 | pixz (Parallel XZ) | 0.10 MB (0.0%) | 0.58 MB (0.1%) | 3258.3 MB/s | 374.2 MB/s | **0.1x** | 1248.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | XZ | 9 | 无 | pixz (Parallel XZ) | 0.07 MB (0.0%) | 0.51 MB (0.1%) | 466.4 MB/s | 330.1 MB/s | **0.7x** | 872.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | LZIP | 1 | 无 | plzip (Multi-thread Lzip) | 0.10 MB (0.0%) | 0.58 MB (0.1%) | 1370.8 MB/s | 377.2 MB/s | **0.3x** | 1071.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | LZIP | 9 | 无 | plzip (Multi-thread Lzip) | 0.07 MB (0.0%) | 0.51 MB (0.1%) | 51.2 MB/s | 330.7 MB/s | **6.5x** | 768.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | LZ4 | 1 | 无 | official lz4 CLI | 1.96 MB (0.4%) | 0.58 MB (0.1%) | 3009.3 MB/s | 381.6 MB/s | **0.1x** | 989.6 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | LZ4 | 9 | 无 | official lz4 CLI | 1.96 MB (0.4%) | 0.51 MB (0.1%) | 3049.3 MB/s | 317.4 MB/s | **0.1x** | 1176.7 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | BROTLI | 1 | 无 | brotli CLI | 0.09 MB (0.0%) | 0.58 MB (0.1%) | 2732.3 MB/s | 369.1 MB/s | **0.1x** | 947.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | BROTLI | 9 | 无 | brotli CLI | 0.00 MB (0.0%) | 0.51 MB (0.1%) | 659.1 MB/s | 328.3 MB/s | **0.5x** | 775.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | LRZIP | 1 | 无 | lrzip (Multi-core) | 0.07 MB (0.0%) | 0.58 MB (0.1%) | 143.7 MB/s | 374.7 MB/s | **2.6x** | 269.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | LRZIP | 9 | 无 | lrzip (Multi-core) | 0.07 MB (0.0%) | 0.51 MB (0.1%) | 98.1 MB/s | 322.6 MB/s | **3.3x** | 266.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | WIM | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.58 MB (0.1%) | 4223.5 MB/s | 370.0 MB/s | **0.1x** | 3691.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | WIM | 9 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.51 MB (0.1%) | 437.6 MB/s | 332.5 MB/s | **0.8x** | 2662.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | DMG | 1 | 无 | macOS hdiutil (DMG) | 0.06 MB (0.0%) | 0.58 MB (0.1%) | 82.4 MB/s | 365.5 MB/s | **4.4x** | 5116.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | DMG | 1 | AES-256 | macOS hdiutil (DMG) | 0.06 MB (0.0%) | 0.58 MB (0.1%) | 82.4 MB/s | 369.0 MB/s | **4.5x** | 6111.7 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | DMG | 9 | 无 | macOS hdiutil (DMG) | 0.06 MB (0.0%) | 0.51 MB (0.1%) | 82.4 MB/s | 319.9 MB/s | **3.9x** | 5910.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | DMG | 9 | AES-256 | macOS hdiutil (DMG) | 0.06 MB (0.0%) | 0.51 MB (0.1%) | 82.4 MB/s | 330.8 MB/s | **4.0x** | 6016.7 MB/s | 0.0 MB/s | **0.0x** | - |
