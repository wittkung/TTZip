# TTZip Exhaustive Competitor Benchmark Report

> **Timestamp**: 2026-08-18 21:42:34 +0000
> **Environment**: Apple Silicon (18 cores [P:6 / E:12]) | macOS 版本26.6.1（版号25G76）
> **Competitors**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **Execution Model**: Competitor tools configured with full concurrency (`-mmt=on`, `-T0`, `-p max`, `-n max`), TTZip executing in-process via 16MB mmap / NEON SIMD / native C architecture

| Dataset Dimension | Archive Format | Level | Encryption | Competitor Tool | Competitor Size (Ratio) | TTZip Size (Ratio) | Competitor Comp (MB/s) | TTZip Comp (MB/s) | Comp Speedup | Competitor Extract (MB/s) | TTZip Extract (MB/s) | Extract Speedup | AOP Bottleneck Stage |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Small Files (10MB/100 files) | 7Z | 1 | None | 7-Zip 7zz CLI (ARM64) | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 896.1 MB/s | 2866.0 MB/s | **3.2x** | 707.9 MB/s | 1682.8 MB/s | **2.4x** | - |
| Small Files (10MB/100 files) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI (ARM64) | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 802.8 MB/s | 1738.4 MB/s | **2.2x** | 481.5 MB/s | 907.1 MB/s | **1.9x** | - |
| Small Files (10MB/100 files) | 7Z | 6 | None | 7-Zip 7zz CLI (ARM64) | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 290.1 MB/s | 687.4 MB/s | **2.4x** | 601.3 MB/s | 1514.1 MB/s | **2.5x** | - |
| Small Files (10MB/100 files) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI (ARM64) | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 280.3 MB/s | 695.4 MB/s | **2.5x** | 444.1 MB/s | 833.7 MB/s | **1.9x** | - |
| Small Files (10MB/100 files) | ZIP | 1 | None | 7-Zip 7zz CLI (ARM64) | 0.06 MB (0.5%) | 0.13 MB (1.1%) | 427.4 MB/s | 7396.9 MB/s | **17.3x** | 559.1 MB/s | 2274.1 MB/s | **4.1x** | - |
| Small Files (10MB/100 files) | ZIP | 1 | AES-256 | 7-Zip 7zz CLI (ARM64) | 0.06 MB (0.5%) | 0.13 MB (1.1%) | 419.2 MB/s | 2350.6 MB/s | **5.6x** | 539.8 MB/s | 2098.1 MB/s | **3.9x** | - |
| Small Files (10MB/100 files) | ZIP | 6 | None | 7-Zip 7zz CLI (ARM64) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 350.0 MB/s | 5954.6 MB/s | **17.0x** | 560.1 MB/s | 2252.6 MB/s | **4.0x** | - |
| Small Files (10MB/100 files) | ZIP | 6 | AES-256 | 7-Zip 7zz CLI (ARM64) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 339.2 MB/s | 2185.2 MB/s | **6.4x** | 556.3 MB/s | 2027.9 MB/s | **3.6x** | - |
| Small Files (10MB/100 files) | TAR.ZST | 1 | None | Zstandard zstd CLI (-T0 All Cores) | 0.01 MB (0.1%) | 0.00 MB (0.0%) | 269.1 MB/s | 4190.5 MB/s | **15.6x** | 269.8 MB/s | 1656.2 MB/s | **6.1x** | - |
| Small Files (10MB/100 files) | TAR.ZST | 6 | None | Zstandard zstd CLI (-T0 All Cores) | 0.01 MB (0.0%) | 0.00 MB (0.0%) | 279.2 MB/s | 3511.0 MB/s | **12.6x** | 268.6 MB/s | 1721.0 MB/s | **6.4x** | - |
| Small Files (10MB/100 files) | TAR.GZ | 1 | None | Parallel pigz (Multi-threaded GZIP) | 0.12 MB (1.0%) | 0.11 MB (0.9%) | 264.2 MB/s | 3694.0 MB/s | **14.0x** | 267.3 MB/s | 1129.2 MB/s | **4.2x** | - |
| Small Files (10MB/100 files) | TAR.GZ | 6 | None | libdeflate-gzip (C Fast Path) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 232.5 MB/s | 3209.8 MB/s | **13.8x** | 268.3 MB/s | 1109.1 MB/s | **4.1x** | - |
| Small Files (10MB/100 files) | TAR.BZ2 | 1 | None | pbzip2 (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.3%) | 87.2 MB/s | 106.2 MB/s | **1.2x** | 186.0 MB/s | 209.8 MB/s | **1.1x** | - |
| Small Files (10MB/100 files) | TAR.BZ2 | 6 | None | pbzip2 (All Cores) | 0.03 MB (0.2%) | 0.01 MB (0.1%) | 68.0 MB/s | 82.6 MB/s | **1.2x** | 129.2 MB/s | 155.0 MB/s | **1.2x** | - |
| Small Files (10MB/100 files) | TAR.XZ | 1 | None | pixz (All Cores) | 0.01 MB (0.1%) | 0.01 MB (0.1%) | 200.7 MB/s | 1677.9 MB/s | **8.4x** | 254.1 MB/s | 98.7 MB/s | **0.4x** | - |
| Small Files (10MB/100 files) | TAR.XZ | 6 | None | pixz (All Cores) | 0.01 MB (0.0%) | 0.01 MB (0.1%) | 99.2 MB/s | 962.9 MB/s | **9.7x** | 229.0 MB/s | 94.5 MB/s | **0.4x** | - |
| Small Files (10MB/100 files) | TAR | 1 | None | 7-Zip 7zz CLI (ARM64) | 11.92 MB (100.8%) | 11.92 MB (100.8%) | 1292.7 MB/s | 2963.5 MB/s | **2.3x** | 849.2 MB/s | 1505.3 MB/s | **1.8x** | - |
| Small Files (10MB/100 files) | TAR | 6 | None | 7-Zip 7zz CLI (ARM64) | 11.92 MB (100.8%) | 11.92 MB (100.8%) | 1354.3 MB/s | 2948.2 MB/s | **2.2x** | 858.1 MB/s | 1508.7 MB/s | **1.8x** | - |
| Small Files (10MB/100 files) | LZIP | 1 | None | plzip (Parallel Lzip) | 0.01 MB (0.1%) | 0.01 MB (0.1%) | 151.3 MB/s | 1360.2 MB/s | **9.0x** | 177.3 MB/s | 97.1 MB/s | **0.5x** | - |
| Small Files (10MB/100 files) | LZIP | 6 | None | plzip (Parallel Lzip) | 0.01 MB (0.0%) | 0.01 MB (0.1%) | 44.5 MB/s | 869.2 MB/s | **19.5x** | 178.1 MB/s | 94.9 MB/s | **0.5x** | - |
| Small Files (10MB/100 files) | LZ4 | 1 | None | lz4 CLI (C11 Native) | 0.10 MB (0.9%) | 0.07 MB (0.6%) | 281.3 MB/s | 3023.8 MB/s | **10.7x** | 262.5 MB/s | 101.7 MB/s | **0.4x** | - |
| Small Files (10MB/100 files) | LZ4 | 6 | None | lz4 CLI (C11 Native) | 0.09 MB (0.8%) | 0.07 MB (0.6%) | 256.5 MB/s | 2733.7 MB/s | **10.7x** | 262.3 MB/s | 101.8 MB/s | **0.4x** | - |
| Small Files (10MB/100 files) | BROTLI | 1 | None | Google Brotli CLI | 0.02 MB (0.2%) | 0.00 MB (0.0%) | 296.7 MB/s | 936.0 MB/s | **3.2x** | 245.9 MB/s | 1169.9 MB/s | **4.8x** | - |
| Small Files (10MB/100 files) | BROTLI | 6 | None | Google Brotli CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 256.6 MB/s | 930.3 MB/s | **3.6x** | 244.8 MB/s | 1205.8 MB/s | **4.9x** | - |
| Small Files (10MB/100 files) | LRZIP | 1 | None | lrzip (Long Range ZIP) | 0.01 MB (0.1%) | 0.01 MB (0.1%) | 144.6 MB/s | 1426.3 MB/s | **9.9x** | 165.7 MB/s | 98.2 MB/s | **0.6x** | - |
| Small Files (10MB/100 files) | LRZIP | 6 | None | lrzip (Long Range ZIP) | 0.01 MB (0.0%) | 0.01 MB (0.1%) | 149.1 MB/s | 886.1 MB/s | **5.9x** | 169.9 MB/s | 94.9 MB/s | **0.6x** | - |
| Small Files (10MB/100 files) | AAR | 1 | None | Apple aa (Apple Archive CLI) | 0.01 MB (0.1%) | 0.01 MB (0.1%) | 540.5 MB/s | 1899.0 MB/s | **3.5x** | 957.7 MB/s | 2175.6 MB/s | **2.3x** | - |
| Small Files (10MB/100 files) | AAR | 6 | None | Apple aa (Apple Archive CLI) | 0.01 MB (0.1%) | 0.01 MB (0.1%) | 603.8 MB/s | 1905.9 MB/s | **3.2x** | 985.3 MB/s | 2176.2 MB/s | **2.2x** | - |
| Small Files (10MB/100 files) | WIM | 1 | None | wimlib-imagex CLI | 0.00 MB (0.0%) | 11.92 MB (100.8%) | 488.6 MB/s | 2952.0 MB/s | **6.0x** | 2192.3 MB/s | 1547.0 MB/s | **0.7x** | - |
| Small Files (10MB/100 files) | WIM | 1 | AES-256 | wimlib-imagex CLI | 0.00 MB (0.0%) | 11.92 MB (100.8%) | 880.0 MB/s | 2976.1 MB/s | **3.4x** | 2366.0 MB/s | 1456.0 MB/s | **0.6x** | - |
| Small Files (10MB/100 files) | WIM | 6 | None | wimlib-imagex CLI | 0.00 MB (0.0%) | 11.92 MB (100.8%) | 855.1 MB/s | 2974.4 MB/s | **3.5x** | 2406.7 MB/s | 1448.5 MB/s | **0.6x** | - |
| Small Files (10MB/100 files) | WIM | 6 | AES-256 | wimlib-imagex CLI | 0.00 MB (0.0%) | 11.92 MB (100.8%) | 856.6 MB/s | 2863.6 MB/s | **3.3x** | 2436.2 MB/s | 1426.2 MB/s | **0.6x** | - |
| Small Files (10MB/100 files) | DMG | 1 | None | Apple hdiutil (macOS Native) | 0.11 MB (1.0%) | 12.29 MB (103.9%) | 0.8 MB/s | 1689.5 MB/s | **2154.2x** | 2.3 MB/s | 1099.7 MB/s | **484.4x** | - |
| Small Files (10MB/100 files) | DMG | 1 | AES-256 | Apple hdiutil (macOS Native) | 0.11 MB (1.0%) | 12.29 MB (103.9%) | 2.9 MB/s | 1679.6 MB/s | **571.9x** | 4.2 MB/s | 1098.3 MB/s | **262.1x** | - |
| Small Files (10MB/100 files) | DMG | 6 | None | Apple hdiutil (macOS Native) | 0.11 MB (1.0%) | 12.29 MB (103.9%) | 2.9 MB/s | 1703.9 MB/s | **580.0x** | 3.1 MB/s | 1087.6 MB/s | **351.0x** | - |
| Small Files (10MB/100 files) | DMG | 6 | AES-256 | Apple hdiutil (macOS Native) | 0.11 MB (1.0%) | 12.29 MB (103.9%) | 2.9 MB/s | 1737.8 MB/s | **591.3x** | 4.1 MB/s | 1076.4 MB/s | **260.8x** | - |
| Log Text (10MB) | 7Z | 1 | None | 7-Zip 7zz CLI (ARM64) | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 972.1 MB/s | 3348.7 MB/s | **3.4x** | 1221.7 MB/s | 8133.7 MB/s | **6.7x** | - |
| Log Text (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI (ARM64) | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 778.2 MB/s | 1393.5 MB/s | **1.8x** | 708.8 MB/s | 1257.0 MB/s | **1.8x** | - |
| Log Text (10MB) | 7Z | 6 | None | 7-Zip 7zz CLI (ARM64) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 291.0 MB/s | 587.0 MB/s | **2.0x** | 896.4 MB/s | 6807.6 MB/s | **7.6x** | - |
| Log Text (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI (ARM64) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 270.6 MB/s | 535.5 MB/s | **2.0x** | 564.7 MB/s | 1191.1 MB/s | **2.1x** | - |
| Log Text (10MB) | ZIP | 1 | None | 7-Zip 7zz CLI (ARM64) | 0.03 MB (0.4%) | 0.09 MB (1.0%) | 599.1 MB/s | 5049.3 MB/s | **8.4x** | 839.3 MB/s | 7414.0 MB/s | **8.8x** | - |
| Log Text (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz CLI (ARM64) | 0.03 MB (0.4%) | 0.09 MB (1.0%) | 525.0 MB/s | 3736.1 MB/s | **7.1x** | 796.2 MB/s | 0.0 MB/s | **0.0x** | - |
| Log Text (10MB) | ZIP | 6 | None | Apple ditto (Native macOS) | 0.03 MB (0.3%) | 0.03 MB (0.3%) | 490.1 MB/s | 3.3 MB/s | **0.0x** | 2004.3 MB/s | 6992.0 MB/s | **3.5x** | - |
| Log Text (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz CLI (ARM64) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 80.1 MB/s | 1224.8 MB/s | **15.3x** | 821.2 MB/s | 4896.6 MB/s | **6.0x** | - |
| Log Text (10MB) | TAR.ZST | 1 | None | Zstandard zstd CLI (-T0 All Cores) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 889.3 MB/s | 9777.4 MB/s | **11.0x** | 859.4 MB/s | 6029.5 MB/s | **7.0x** | - |
| Log Text (10MB) | TAR.ZST | 6 | None | Zstandard zstd CLI (-T0 All Cores) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 768.0 MB/s | 5703.9 MB/s | **7.4x** | 885.4 MB/s | 5887.7 MB/s | **6.6x** | - |
| Log Text (10MB) | TAR.GZ | 1 | None | Parallel pigz (Multi-threaded GZIP) | 0.07 MB (0.7%) | 0.09 MB (1.0%) | 652.9 MB/s | 8270.5 MB/s | **12.7x** | 771.7 MB/s | 5198.5 MB/s | **6.7x** | - |
| Log Text (10MB) | TAR.GZ | 6 | None | Parallel pigz (Multi-threaded GZIP) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 689.4 MB/s | 5260.3 MB/s | **7.6x** | 766.8 MB/s | 5372.9 MB/s | **7.0x** | - |
| Log Text (10MB) | TAR.BZ2 | 1 | None | pbzip2 (All Cores) | 0.03 MB (0.3%) | 0.03 MB (0.3%) | 91.4 MB/s | 89.0 MB/s | **1.0x** | 217.2 MB/s | 258.2 MB/s | **1.2x** | - |
| Log Text (10MB) | TAR.BZ2 | 6 | None | pbzip2 (All Cores) | 0.01 MB (0.1%) | 0.01 MB (0.1%) | 77.4 MB/s | 79.5 MB/s | **1.0x** | 215.5 MB/s | 249.4 MB/s | **1.2x** | - |
| Log Text (10MB) | TAR.XZ | 1 | None | pixz (All Cores) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 512.4 MB/s | 1960.0 MB/s | **3.8x** | 666.5 MB/s | 80.7 MB/s | **0.1x** | - |
| Log Text (10MB) | TAR.XZ | 6 | None | pixz (All Cores) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 154.7 MB/s | 877.0 MB/s | **5.7x** | 380.2 MB/s | 78.9 MB/s | **0.2x** | - |
| Log Text (10MB) | TAR | 1 | None | 7-Zip 7zz CLI (ARM64) | 9.35 MB (100.0%) | 9.35 MB (100.0%) | 1301.6 MB/s | 4582.7 MB/s | **3.5x** | 1366.5 MB/s | 7195.2 MB/s | **5.3x** | - |
| Log Text (10MB) | TAR | 6 | None | 7-Zip 7zz CLI (ARM64) | 9.35 MB (100.0%) | 9.35 MB (100.0%) | 1411.1 MB/s | 4616.5 MB/s | **3.3x** | 1430.3 MB/s | 7220.5 MB/s | **5.0x** | - |
| Log Text (10MB) | LZIP | 1 | None | plzip (Parallel Lzip) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 279.9 MB/s | 1438.4 MB/s | **5.1x** | 422.7 MB/s | 80.8 MB/s | **0.2x** | - |
| Log Text (10MB) | LZIP | 6 | None | plzip (Parallel Lzip) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 52.0 MB/s | 838.4 MB/s | **16.1x** | 253.1 MB/s | 79.3 MB/s | **0.3x** | - |
| Log Text (10MB) | LZ4 | 1 | None | lz4 CLI (C11 Native) | 0.04 MB (0.4%) | 0.05 MB (0.6%) | 725.4 MB/s | 5267.1 MB/s | **7.3x** | 762.2 MB/s | 85.3 MB/s | **0.1x** | - |
| Log Text (10MB) | LZ4 | 6 | None | lz4 CLI (C11 Native) | 0.04 MB (0.4%) | 0.05 MB (0.6%) | 715.8 MB/s | 5200.1 MB/s | **7.3x** | 816.1 MB/s | 85.0 MB/s | **0.1x** | - |
| Log Text (10MB) | BROTLI | 1 | None | Google Brotli CLI | 0.00 MB (0.1%) | 0.00 MB (0.0%) | 907.8 MB/s | 1157.2 MB/s | **1.3x** | 652.9 MB/s | 1582.7 MB/s | **2.4x** | - |
| Log Text (10MB) | BROTLI | 6 | None | Google Brotli CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 511.4 MB/s | 1149.6 MB/s | **2.2x** | 589.3 MB/s | 1538.0 MB/s | **2.6x** | - |
| Log Text (10MB) | LRZIP | 1 | None | lrzip (Long Range ZIP) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 293.5 MB/s | 1560.6 MB/s | **5.3x** | 317.4 MB/s | 80.8 MB/s | **0.3x** | - |
| Log Text (10MB) | LRZIP | 6 | None | lrzip (Long Range ZIP) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 297.8 MB/s | 796.0 MB/s | **2.7x** | 321.4 MB/s | 78.8 MB/s | **0.2x** | - |
| Log Text (10MB) | AAR | 1 | None | Apple aa (Apple Archive CLI) | 0.01 MB (0.1%) | 0.01 MB (0.1%) | 4397.9 MB/s | 1625.6 MB/s | **0.4x** | 3890.6 MB/s | 2591.3 MB/s | **0.7x** | - |
| Log Text (10MB) | AAR | 6 | None | Apple aa (Apple Archive CLI) | 0.01 MB (0.1%) | 0.01 MB (0.1%) | 3509.2 MB/s | 1592.7 MB/s | **0.5x** | 3456.5 MB/s | 2572.8 MB/s | **0.7x** | - |
| Log Text (10MB) | WIM | 1 | None | wimlib-imagex CLI | 9.35 MB (100.0%) | 9.35 MB (100.0%) | 1802.4 MB/s | 4843.3 MB/s | **2.7x** | 1716.1 MB/s | 8020.3 MB/s | **4.7x** | - |
| Log Text (10MB) | WIM | 1 | AES-256 | wimlib-imagex CLI | 9.35 MB (100.0%) | 9.35 MB (100.0%) | 1868.3 MB/s | 4874.2 MB/s | **2.6x** | 2003.3 MB/s | 7736.0 MB/s | **3.9x** | - |
| Log Text (10MB) | WIM | 6 | None | wimlib-imagex CLI | 9.35 MB (100.0%) | 9.35 MB (100.0%) | 1864.1 MB/s | 4990.7 MB/s | **2.7x** | 2053.7 MB/s | 8176.7 MB/s | **4.0x** | - |
| Log Text (10MB) | WIM | 6 | AES-256 | wimlib-imagex CLI | 9.35 MB (100.0%) | 9.35 MB (100.0%) | 1770.6 MB/s | 4974.8 MB/s | **2.8x** | 2252.3 MB/s | 8074.3 MB/s | **3.6x** | - |
| Log Text (10MB) | DMG | 1 | None | Apple hdiutil (macOS Native) | 0.09 MB (0.9%) | 9.70 MB (103.8%) | 2.3 MB/s | 2849.2 MB/s | **1227.6x** | 3.0 MB/s | 5646.0 MB/s | **1866.4x** | - |
| Log Text (10MB) | DMG | 1 | AES-256 | Apple hdiutil (macOS Native) | 0.09 MB (0.9%) | 9.70 MB (103.8%) | 2.3 MB/s | 2608.1 MB/s | **1123.6x** | 3.2 MB/s | 4973.2 MB/s | **1552.4x** | - |
| Log Text (10MB) | DMG | 6 | None | Apple hdiutil (macOS Native) | 0.09 MB (0.9%) | 9.70 MB (103.8%) | 2.3 MB/s | 2658.8 MB/s | **1144.1x** | 4.8 MB/s | 5123.2 MB/s | **1067.3x** | - |
| Log Text (10MB) | DMG | 6 | AES-256 | Apple hdiutil (macOS Native) | 0.09 MB (0.9%) | 9.70 MB (103.8%) | 2.3 MB/s | 2850.6 MB/s | **1227.5x** | 3.2 MB/s | 5332.2 MB/s | **1680.8x** | - |
| Float32 Sensor Matrix (50MB) | 7Z | 1 | None | 7-Zip 7zz CLI (ARM64) | 27.20 MB (54.4%) | 27.14 MB (54.3%) | 259.6 MB/s | 351.5 MB/s | **1.4x** | 835.9 MB/s | 758.1 MB/s | **0.9x** | - |
| Float32 Sensor Matrix (50MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI (ARM64) | 27.20 MB (54.4%) | 27.14 MB (54.3%) | 266.9 MB/s | 329.2 MB/s | **1.2x** | 705.1 MB/s | 709.3 MB/s | **1.0x** | - |
| Float32 Sensor Matrix (50MB) | 7Z | 6 | None | 7-Zip 7zz CLI (ARM64) | 25.80 MB (51.6%) | 26.03 MB (52.1%) | 21.0 MB/s | 56.4 MB/s | **2.7x** | 69.7 MB/s | 659.0 MB/s | **9.5x** | - |
| Float32 Sensor Matrix (50MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI (ARM64) | 25.80 MB (51.6%) | 26.03 MB (52.1%) | 20.9 MB/s | 55.6 MB/s | **2.7x** | 68.5 MB/s | 605.1 MB/s | **8.8x** | - |
| Float32 Sensor Matrix (50MB) | ZIP | 1 | None | 7-Zip 7zz CLI (ARM64) | 45.88 MB (91.8%) | 45.52 MB (91.0%) | 70.3 MB/s | 179.2 MB/s | **2.5x** | 225.4 MB/s | 577.7 MB/s | **2.6x** | - |
| Float32 Sensor Matrix (50MB) | ZIP | 1 | AES-256 | 7-Zip 7zz CLI (ARM64) | 45.88 MB (91.8%) | 45.52 MB (91.0%) | 60.7 MB/s | 168.3 MB/s | **2.8x** | 92.6 MB/s | 0.0 MB/s | **0.0x** | - |
| Float32 Sensor Matrix (50MB) | ZIP | 6 | None | 7-Zip 7zz CLI (ARM64) | 45.68 MB (91.4%) | 45.49 MB (91.0%) | 54.4 MB/s | 22.8 MB/s | **0.4x** | 242.1 MB/s | 573.6 MB/s | **2.4x** | - |
| Float32 Sensor Matrix (50MB) | ZIP | 6 | AES-256 | 7-Zip 7zz CLI (ARM64) | 45.68 MB (91.4%) | 45.56 MB (91.1%) | 50.0 MB/s | 128.3 MB/s | **2.6x** | 92.3 MB/s | 0.0 MB/s | **0.0x** | - |
| Float32 Sensor Matrix (50MB) | TAR.ZST | 1 | None | Zstandard zstd CLI (-T0 All Cores) | 45.50 MB (91.0%) | 45.50 MB (91.0%) | 1723.3 MB/s | 3188.4 MB/s | **1.9x** | 1040.5 MB/s | 1042.0 MB/s | **1.0x** | - |
| Float32 Sensor Matrix (50MB) | TAR.ZST | 6 | None | Zstandard zstd CLI (-T0 All Cores) | 45.51 MB (91.0%) | 45.50 MB (91.0%) | 1236.9 MB/s | 3108.0 MB/s | **2.5x** | 1086.3 MB/s | 1091.3 MB/s | **1.0x** | - |
| Float32 Sensor Matrix (50MB) | TAR.GZ | 1 | None | Parallel pigz (Multi-threaded GZIP) | 45.85 MB (91.7%) | 45.52 MB (91.0%) | 577.0 MB/s | 1783.4 MB/s | **3.1x** | 443.9 MB/s | 536.2 MB/s | **1.2x** | - |
| Float32 Sensor Matrix (50MB) | TAR.GZ | 6 | None | Parallel pigz (Multi-threaded GZIP) | 45.64 MB (91.3%) | 45.56 MB (91.1%) | 458.6 MB/s | 1340.1 MB/s | **2.9x** | 483.9 MB/s | 506.8 MB/s | **1.0x** | - |
| Float32 Sensor Matrix (50MB) | TAR.BZ2 | 1 | None | pbzip2 (All Cores) | 46.25 MB (92.5%) | 46.27 MB (92.5%) | 208.0 MB/s | 251.0 MB/s | **1.2x** | 405.6 MB/s | 35.4 MB/s | **0.1x** | - |
| Float32 Sensor Matrix (50MB) | TAR.BZ2 | 6 | None | pbzip2 (All Cores) | 45.42 MB (90.8%) | 45.38 MB (90.8%) | 195.2 MB/s | 227.0 MB/s | **1.2x** | 377.2 MB/s | 31.9 MB/s | **0.1x** | - |
| Float32 Sensor Matrix (50MB) | TAR.XZ | 1 | None | pixz (All Cores) | 27.09 MB (54.2%) | 27.36 MB (54.7%) | 87.7 MB/s | 134.2 MB/s | **1.5x** | 537.5 MB/s | 48.8 MB/s | **0.1x** | - |
| Float32 Sensor Matrix (50MB) | TAR.XZ | 6 | None | pixz (All Cores) | 25.89 MB (51.8%) | 26.63 MB (53.3%) | 13.2 MB/s | 109.1 MB/s | **8.3x** | 157.4 MB/s | 49.5 MB/s | **0.3x** | - |
| Float32 Sensor Matrix (50MB) | TAR | 1 | None | 7-Zip 7zz CLI (ARM64) | 50.00 MB (100.0%) | 50.00 MB (100.0%) | 3940.8 MB/s | 5406.4 MB/s | **1.4x** | 4031.1 MB/s | 7919.8 MB/s | **2.0x** | - |
| Float32 Sensor Matrix (50MB) | TAR | 6 | None | 7-Zip 7zz CLI (ARM64) | 50.00 MB (100.0%) | 50.00 MB (100.0%) | 3933.7 MB/s | 5541.1 MB/s | **1.4x** | 4113.8 MB/s | 8079.0 MB/s | **2.0x** | - |
| Float32 Sensor Matrix (50MB) | LZIP | 1 | None | plzip (Parallel Lzip) | 26.38 MB (52.8%) | 27.36 MB (54.7%) | 51.9 MB/s | 132.9 MB/s | **2.6x** | 273.2 MB/s | 48.8 MB/s | **0.2x** | - |
| Float32 Sensor Matrix (50MB) | LZIP | 6 | None | plzip (Parallel Lzip) | 25.90 MB (51.8%) | 26.63 MB (53.3%) | 10.2 MB/s | 115.0 MB/s | **11.3x** | 109.0 MB/s | 49.6 MB/s | **0.5x** | - |
| Float32 Sensor Matrix (50MB) | LZ4 | 1 | None | lz4 CLI (C11 Native) | 50.01 MB (100.0%) | 50.00 MB (100.0%) | 1638.5 MB/s | 4782.1 MB/s | **2.9x** | 1416.6 MB/s | 369.8 MB/s | **0.3x** | - |
| Float32 Sensor Matrix (50MB) | LZ4 | 6 | None | lz4 CLI (C11 Native) | 50.01 MB (100.0%) | 50.00 MB (100.0%) | 535.3 MB/s | 1227.4 MB/s | **2.3x** | 1457.9 MB/s | 352.0 MB/s | **0.2x** | - |
| Float32 Sensor Matrix (50MB) | BROTLI | 1 | None | Google Brotli CLI | 45.51 MB (91.0%) | 45.54 MB (91.1%) | 369.4 MB/s | 322.5 MB/s | **0.9x** | 215.3 MB/s | 244.8 MB/s | **1.1x** | - |
| Float32 Sensor Matrix (50MB) | BROTLI | 6 | None | Google Brotli CLI | 26.85 MB (53.7%) | 45.54 MB (91.1%) | 62.8 MB/s | 332.2 MB/s | **5.3x** | 310.4 MB/s | 250.8 MB/s | **0.8x** | - |
| Float32 Sensor Matrix (50MB) | LRZIP | 1 | None | lrzip (Long Range ZIP) | 50.00 MB (100.0%) | 27.36 MB (54.7%) | 228.0 MB/s | 132.6 MB/s | **0.6x** | 353.3 MB/s | 48.2 MB/s | **0.1x** | - |
| Float32 Sensor Matrix (50MB) | LRZIP | 6 | None | lrzip (Long Range ZIP) | 50.00 MB (100.0%) | 26.63 MB (53.3%) | 84.7 MB/s | 110.3 MB/s | **1.3x** | 352.0 MB/s | 48.8 MB/s | **0.1x** | - |
| Float32 Sensor Matrix (50MB) | AAR | 1 | None | Apple aa (Apple Archive CLI) | 46.24 MB (92.5%) | 46.24 MB (92.5%) | 18799.3 MB/s | 2097.4 MB/s | **0.1x** | 19798.1 MB/s | 2748.6 MB/s | **0.1x** | - |
| Float32 Sensor Matrix (50MB) | AAR | 6 | None | Apple aa (Apple Archive CLI) | 46.24 MB (92.5%) | 46.24 MB (92.5%) | 18857.8 MB/s | 2092.7 MB/s | **0.1x** | 19094.6 MB/s | 2824.3 MB/s | **0.1x** | - |
| Float32 Sensor Matrix (50MB) | WIM | 1 | None | wimlib-imagex CLI | 50.00 MB (100.0%) | 50.00 MB (100.0%) | 9904.5 MB/s | 5532.5 MB/s | **0.6x** | 11621.9 MB/s | 8214.3 MB/s | **0.7x** | - |
| Float32 Sensor Matrix (50MB) | WIM | 1 | AES-256 | wimlib-imagex CLI | 50.00 MB (100.0%) | 50.00 MB (100.0%) | 9774.2 MB/s | 5733.3 MB/s | **0.6x** | 12091.9 MB/s | 8271.4 MB/s | **0.7x** | - |
| Float32 Sensor Matrix (50MB) | WIM | 6 | None | wimlib-imagex CLI | 50.00 MB (100.0%) | 50.00 MB (100.0%) | 9964.4 MB/s | 5675.2 MB/s | **0.6x** | 11530.0 MB/s | 8215.3 MB/s | **0.7x** | - |
| Float32 Sensor Matrix (50MB) | WIM | 6 | AES-256 | wimlib-imagex CLI | 50.00 MB (100.0%) | 50.00 MB (100.0%) | 9711.8 MB/s | 5748.3 MB/s | **0.6x** | 12389.7 MB/s | 8264.2 MB/s | **0.7x** | - |
| Float32 Sensor Matrix (50MB) | DMG | 1 | None | Apple hdiutil (macOS Native) | 46.85 MB (93.7%) | 50.35 MB (100.7%) | 8.3 MB/s | 3136.0 MB/s | **378.2x** | 18.8 MB/s | 5550.1 MB/s | **295.9x** | - |
| Float32 Sensor Matrix (50MB) | DMG | 1 | AES-256 | Apple hdiutil (macOS Native) | 46.85 MB (93.7%) | 50.35 MB (100.7%) | 9.9 MB/s | 2210.2 MB/s | **222.3x** | 26.1 MB/s | 4771.9 MB/s | **182.9x** | - |
| Float32 Sensor Matrix (50MB) | DMG | 6 | None | Apple hdiutil (macOS Native) | 46.85 MB (93.7%) | 50.35 MB (100.7%) | 9.9 MB/s | 3118.1 MB/s | **313.5x** | 27.0 MB/s | 4780.9 MB/s | **177.1x** | - |
| Float32 Sensor Matrix (50MB) | DMG | 6 | AES-256 | Apple hdiutil (macOS Native) | 46.85 MB (93.7%) | 50.35 MB (100.7%) | 9.9 MB/s | 1977.0 MB/s | **198.8x** | 17.4 MB/s | 5424.5 MB/s | **311.2x** | - |
| Structured JSON (50MB) | 7Z | 1 | None | 7-Zip 7zz CLI (ARM64) | 0.01 MB (0.0%) | 0.01 MB (0.0%) | 2280.4 MB/s | 3953.2 MB/s | **1.7x** | 2916.4 MB/s | 9186.9 MB/s | **3.2x** | - |
| Structured JSON (50MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI (ARM64) | 0.01 MB (0.0%) | 0.01 MB (0.0%) | 2249.1 MB/s | 4047.8 MB/s | **1.8x** | 1964.0 MB/s | 3708.8 MB/s | **1.9x** | - |
| Structured JSON (50MB) | 7Z | 6 | None | 7-Zip 7zz CLI (ARM64) | 0.01 MB (0.0%) | 0.01 MB (0.0%) | 327.8 MB/s | 1330.2 MB/s | **4.1x** | 1405.6 MB/s | 9415.9 MB/s | **6.7x** | - |
| Structured JSON (50MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI (ARM64) | 0.01 MB (0.0%) | 0.01 MB (0.0%) | 331.3 MB/s | 1383.9 MB/s | **4.2x** | 1133.0 MB/s | 3784.5 MB/s | **3.3x** | - |
| Structured JSON (50MB) | ZIP | 1 | None | 7-Zip 7zz CLI (ARM64) | 0.16 MB (0.4%) | 0.39 MB (1.0%) | 834.4 MB/s | 4816.3 MB/s | **5.8x** | 1384.4 MB/s | 8081.8 MB/s | **5.8x** | - |
| Structured JSON (50MB) | ZIP | 1 | AES-256 | 7-Zip 7zz CLI (ARM64) | 0.16 MB (0.4%) | 0.39 MB (1.0%) | 732.0 MB/s | 4269.8 MB/s | **5.8x** | 1327.2 MB/s | 0.0 MB/s | **0.0x** | - |
| Structured JSON (50MB) | ZIP | 6 | None | Apple ditto (Native macOS) | 0.15 MB (0.4%) | 0.15 MB (0.4%) | 531.1 MB/s | 5.7 MB/s | **0.0x** | 4608.4 MB/s | 8755.3 MB/s | **1.9x** | - |
| Structured JSON (50MB) | ZIP | 6 | AES-256 | 7-Zip 7zz CLI (ARM64) | 0.16 MB (0.4%) | 0.15 MB (0.4%) | 71.0 MB/s | 1316.3 MB/s | **18.5x** | 761.7 MB/s | 0.0 MB/s | **0.0x** | - |
| Structured JSON (50MB) | TAR.ZST | 1 | None | Zstandard zstd CLI (-T0 All Cores) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1947.1 MB/s | 15812.1 MB/s | **8.1x** | 1437.6 MB/s | 4577.6 MB/s | **3.2x** | - |
| Structured JSON (50MB) | TAR.ZST | 6 | None | Zstandard zstd CLI (-T0 All Cores) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1779.7 MB/s | 12165.0 MB/s | **6.8x** | 1455.7 MB/s | 5330.4 MB/s | **3.7x** | - |
| Structured JSON (50MB) | TAR.GZ | 1 | None | Parallel pigz (Multi-threaded GZIP) | 0.29 MB (0.8%) | 0.40 MB (1.0%) | 1334.2 MB/s | 10713.6 MB/s | **8.0x** | 1326.8 MB/s | 5283.6 MB/s | **4.0x** | - |
| Structured JSON (50MB) | TAR.GZ | 6 | None | Parallel pigz (Multi-threaded GZIP) | 0.16 MB (0.4%) | 0.16 MB (0.4%) | 1377.1 MB/s | 8687.4 MB/s | **6.3x** | 1390.2 MB/s | 6236.4 MB/s | **4.5x** | - |
| Structured JSON (50MB) | TAR.BZ2 | 1 | None | pbzip2 (All Cores) | 0.15 MB (0.4%) | 0.15 MB (0.4%) | 128.6 MB/s | 123.8 MB/s | **1.0x** | 237.1 MB/s | 250.2 MB/s | **1.1x** | - |
| Structured JSON (50MB) | TAR.BZ2 | 6 | None | pbzip2 (All Cores) | 0.04 MB (0.1%) | 0.03 MB (0.1%) | 99.7 MB/s | 96.3 MB/s | **1.0x** | 224.1 MB/s | 243.6 MB/s | **1.1x** | - |
| Structured JSON (50MB) | TAR.XZ | 1 | None | pixz (All Cores) | 0.01 MB (0.0%) | 0.01 MB (0.0%) | 1092.6 MB/s | 2905.5 MB/s | **2.7x** | 1202.3 MB/s | 270.8 MB/s | **0.2x** | - |
| Structured JSON (50MB) | TAR.XZ | 6 | None | pixz (All Cores) | 0.01 MB (0.0%) | 0.01 MB (0.0%) | 312.0 MB/s | 1484.6 MB/s | **4.8x** | 984.7 MB/s | 259.1 MB/s | **0.3x** | - |
| Structured JSON (50MB) | TAR | 1 | None | 7-Zip 7zz CLI (ARM64) | 38.63 MB (100.0%) | 38.63 MB (100.0%) | 3604.6 MB/s | 5732.4 MB/s | **1.6x** | 3920.6 MB/s | 9996.7 MB/s | **2.5x** | - |
| Structured JSON (50MB) | TAR | 6 | None | 7-Zip 7zz CLI (ARM64) | 38.63 MB (100.0%) | 38.63 MB (100.0%) | 3630.1 MB/s | 5643.4 MB/s | **1.6x** | 3940.9 MB/s | 9553.4 MB/s | **2.4x** | - |
| Structured JSON (50MB) | LZIP | 1 | None | plzip (Parallel Lzip) | 0.01 MB (0.0%) | 0.01 MB (0.0%) | 651.4 MB/s | 2929.6 MB/s | **4.5x** | 990.2 MB/s | 271.7 MB/s | **0.3x** | - |
| Structured JSON (50MB) | LZIP | 6 | None | plzip (Parallel Lzip) | 0.01 MB (0.0%) | 0.01 MB (0.0%) | 116.5 MB/s | 1428.5 MB/s | **12.3x** | 604.2 MB/s | 256.6 MB/s | **0.4x** | - |
| Structured JSON (50MB) | LZ4 | 1 | None | lz4 CLI (C11 Native) | 0.15 MB (0.4%) | 0.24 MB (0.6%) | 1550.2 MB/s | 10457.0 MB/s | **6.7x** | 1490.6 MB/s | 319.9 MB/s | **0.2x** | - |
| Structured JSON (50MB) | LZ4 | 6 | None | lz4 CLI (C11 Native) | 0.15 MB (0.4%) | 0.24 MB (0.6%) | 1472.5 MB/s | 11288.3 MB/s | **7.7x** | 1482.9 MB/s | 320.2 MB/s | **0.2x** | - |
| Structured JSON (50MB) | BROTLI | 1 | None | Google Brotli CLI | 0.02 MB (0.0%) | 0.00 MB (0.0%) | 2119.8 MB/s | 1188.6 MB/s | **0.6x** | 1111.3 MB/s | 1679.9 MB/s | **1.5x** | - |
| Structured JSON (50MB) | BROTLI | 6 | None | Google Brotli CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 893.8 MB/s | 1183.9 MB/s | **1.3x** | 947.6 MB/s | 1723.9 MB/s | **1.8x** | - |
| Structured JSON (50MB) | LRZIP | 1 | None | lrzip (Long Range ZIP) | 0.00 MB (0.0%) | 0.01 MB (0.0%) | 364.2 MB/s | 2788.4 MB/s | **7.7x** | 380.3 MB/s | 271.7 MB/s | **0.7x** | - |
| Structured JSON (50MB) | LRZIP | 6 | None | lrzip (Long Range ZIP) | 0.00 MB (0.0%) | 0.01 MB (0.0%) | 375.0 MB/s | 1453.9 MB/s | **3.9x** | 393.6 MB/s | 262.0 MB/s | **0.7x** | - |
| Structured JSON (50MB) | AAR | 1 | None | Apple aa (Apple Archive CLI) | 0.03 MB (0.1%) | 0.03 MB (0.1%) | 14173.9 MB/s | 3709.2 MB/s | **0.3x** | 15726.3 MB/s | 2963.0 MB/s | **0.2x** | - |
| Structured JSON (50MB) | AAR | 6 | None | Apple aa (Apple Archive CLI) | 0.03 MB (0.1%) | 0.03 MB (0.1%) | 14802.9 MB/s | 3816.6 MB/s | **0.3x** | 14926.8 MB/s | 3086.9 MB/s | **0.2x** | - |
| Structured JSON (50MB) | WIM | 1 | None | wimlib-imagex CLI | 38.63 MB (100.0%) | 38.63 MB (100.0%) | 7203.3 MB/s | 5407.8 MB/s | **0.8x** | 9025.1 MB/s | 9023.2 MB/s | **1.0x** | - |
| Structured JSON (50MB) | WIM | 1 | AES-256 | wimlib-imagex CLI | 38.63 MB (100.0%) | 38.63 MB (100.0%) | 7692.4 MB/s | 5557.6 MB/s | **0.7x** | 8535.1 MB/s | 9450.1 MB/s | **1.1x** | - |
| Structured JSON (50MB) | WIM | 6 | None | wimlib-imagex CLI | 38.63 MB (100.0%) | 38.63 MB (100.0%) | 7337.9 MB/s | 5548.1 MB/s | **0.8x** | 9125.7 MB/s | 9109.7 MB/s | **1.0x** | - |
| Structured JSON (50MB) | WIM | 6 | AES-256 | wimlib-imagex CLI | 38.63 MB (100.0%) | 38.63 MB (100.0%) | 7539.2 MB/s | 5464.5 MB/s | **0.7x** | 9109.2 MB/s | 9316.7 MB/s | **1.0x** | - |
| Structured JSON (50MB) | DMG | 1 | None | Apple hdiutil (macOS Native) | 0.31 MB (0.8%) | 38.98 MB (100.9%) | 9.6 MB/s | 3482.3 MB/s | **362.7x** | 12.3 MB/s | 6573.2 MB/s | **534.9x** | - |
| Structured JSON (50MB) | DMG | 1 | AES-256 | Apple hdiutil (macOS Native) | 0.31 MB (0.8%) | 38.98 MB (100.9%) | 9.6 MB/s | 2962.5 MB/s | **308.9x** | 13.2 MB/s | 5530.1 MB/s | **417.8x** | - |
| Structured JSON (50MB) | DMG | 6 | None | Apple hdiutil (macOS Native) | 0.31 MB (0.8%) | 38.98 MB (100.9%) | 9.6 MB/s | 3145.6 MB/s | **327.6x** | 9.8 MB/s | 6200.2 MB/s | **635.0x** | - |
| Structured JSON (50MB) | DMG | 6 | AES-256 | Apple hdiutil (macOS Native) | 0.31 MB (0.8%) | 38.98 MB (100.9%) | 9.6 MB/s | 2997.2 MB/s | **312.3x** | 13.4 MB/s | 5587.4 MB/s | **417.0x** | - |
| High-Entropy Payload (100MB) | 7Z | 1 | None | 7-Zip 7zz CLI (ARM64) | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 199.6 MB/s | 4237.8 MB/s | **21.2x** | 3580.4 MB/s | 6560.6 MB/s | **1.8x** | - |
| High-Entropy Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI (ARM64) | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 193.2 MB/s | 1324.7 MB/s | **6.9x** | 3275.6 MB/s | 5662.1 MB/s | **1.7x** | - |
| High-Entropy Payload (100MB) | 7Z | 6 | None | 7-Zip 7zz CLI (ARM64) | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 20.5 MB/s | 5606.0 MB/s | **274.0x** | 2397.5 MB/s | 7167.3 MB/s | **3.0x** | - |
| High-Entropy Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI (ARM64) | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 20.6 MB/s | 1311.5 MB/s | **63.8x** | 1702.6 MB/s | 5915.5 MB/s | **3.5x** | - |
| High-Entropy Payload (100MB) | ZIP | 1 | None | 7-Zip 7zz CLI (ARM64) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 83.5 MB/s | 173.6 MB/s | **2.1x** | 3526.5 MB/s | 9862.1 MB/s | **2.8x** | - |
| High-Entropy Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz CLI (ARM64) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 64.2 MB/s | 164.4 MB/s | **2.6x** | 142.4 MB/s | 2202.1 MB/s | **15.5x** | - |
| High-Entropy Payload (100MB) | ZIP | 6 | None | Apple ditto (Native macOS) | 100.03 MB (100.0%) | 100.00 MB (100.0%) | 78.4 MB/s | 4738.2 MB/s | **60.5x** | 4999.9 MB/s | 10042.1 MB/s | **2.0x** | - |
| High-Entropy Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz CLI (ARM64) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 56.1 MB/s | 135.3 MB/s | **2.4x** | 141.4 MB/s | 2195.7 MB/s | **15.5x** | - |
| High-Entropy Payload (100MB) | TAR.ZST | 1 | None | Zstandard zstd CLI (-T0 All Cores) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 2701.3 MB/s | 4765.9 MB/s | **1.8x** | 1449.4 MB/s | 4399.4 MB/s | **3.0x** | - |
| High-Entropy Payload (100MB) | TAR.ZST | 6 | None | Zstandard zstd CLI (-T0 All Cores) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 2475.5 MB/s | 4931.5 MB/s | **2.0x** | 1475.8 MB/s | 4668.8 MB/s | **3.2x** | - |
| High-Entropy Payload (100MB) | TAR.GZ | 1 | None | Parallel pigz (Multi-threaded GZIP) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 817.7 MB/s | 1831.7 MB/s | **2.2x** | 1354.2 MB/s | 5161.4 MB/s | **3.8x** | - |
| High-Entropy Payload (100MB) | TAR.GZ | 6 | None | Parallel pigz (Multi-threaded GZIP) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 836.2 MB/s | 1568.3 MB/s | **1.9x** | 1370.5 MB/s | 5446.0 MB/s | **4.0x** | - |
| High-Entropy Payload (100MB) | TAR.BZ2 | 1 | None | pbzip2 (All Cores) | 100.81 MB (100.8%) | 100.82 MB (100.8%) | 226.0 MB/s | 216.7 MB/s | **1.0x** | 505.7 MB/s | 39.1 MB/s | **0.1x** | - |
| High-Entropy Payload (100MB) | TAR.BZ2 | 6 | None | pbzip2 (All Cores) | 100.54 MB (100.5%) | 100.54 MB (100.5%) | 221.5 MB/s | 230.6 MB/s | **1.0x** | 436.6 MB/s | 33.7 MB/s | **0.1x** | - |
| High-Entropy Payload (100MB) | TAR.XZ | 1 | None | pixz (All Cores) | 100.01 MB (100.0%) | 100.01 MB (100.0%) | 73.2 MB/s | 105.8 MB/s | **1.4x** | 1587.2 MB/s | 577.1 MB/s | **0.4x** | - |
| High-Entropy Payload (100MB) | TAR.XZ | 6 | None | pixz (All Cores) | 100.01 MB (100.0%) | 100.01 MB (100.0%) | 23.9 MB/s | 121.4 MB/s | **5.1x** | 1175.3 MB/s | 542.5 MB/s | **0.5x** | - |
| High-Entropy Payload (100MB) | TAR | 1 | None | 7-Zip 7zz CLI (ARM64) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4879.4 MB/s | 5418.8 MB/s | **1.1x** | 5206.3 MB/s | 8778.5 MB/s | **1.7x** | - |
| High-Entropy Payload (100MB) | TAR | 6 | None | 7-Zip 7zz CLI (ARM64) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4967.7 MB/s | 5612.7 MB/s | **1.1x** | 5056.5 MB/s | 9474.5 MB/s | **1.9x** | - |
| High-Entropy Payload (100MB) | LZIP | 1 | None | plzip (Parallel Lzip) | 101.36 MB (101.4%) | 100.01 MB (100.0%) | 53.0 MB/s | 99.8 MB/s | **1.9x** | 200.7 MB/s | 576.5 MB/s | **2.9x** | - |
| High-Entropy Payload (100MB) | LZIP | 6 | None | plzip (Parallel Lzip) | 101.36 MB (101.4%) | 100.01 MB (100.0%) | 18.9 MB/s | 116.4 MB/s | **6.1x** | 103.5 MB/s | 575.1 MB/s | **5.6x** | - |
| High-Entropy Payload (100MB) | LZ4 | 1 | None | lz4 CLI (C11 Native) | 100.00 MB (100.0%) | 100.01 MB (100.0%) | 1973.0 MB/s | 5057.2 MB/s | **2.6x** | 1631.5 MB/s | 613.0 MB/s | **0.4x** | - |
| High-Entropy Payload (100MB) | LZ4 | 6 | None | lz4 CLI (C11 Native) | 100.00 MB (100.0%) | 100.01 MB (100.0%) | 648.0 MB/s | 1266.2 MB/s | **2.0x** | 1517.7 MB/s | 606.4 MB/s | **0.4x** | - |
| High-Entropy Payload (100MB) | BROTLI | 1 | None | Google Brotli CLI | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 2249.7 MB/s | 1605.3 MB/s | **0.7x** | 1390.7 MB/s | 3662.6 MB/s | **2.6x** | - |
| High-Entropy Payload (100MB) | BROTLI | 6 | None | Google Brotli CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 717.7 MB/s | 1628.4 MB/s | **2.3x** | 1559.6 MB/s | 3821.7 MB/s | **2.5x** | - |
| High-Entropy Payload (100MB) | LRZIP | 1 | None | lrzip (Long Range ZIP) | 100.00 MB (100.0%) | 100.01 MB (100.0%) | 235.7 MB/s | 94.9 MB/s | **0.4x** | 371.7 MB/s | 559.9 MB/s | **1.5x** | - |
| High-Entropy Payload (100MB) | LRZIP | 6 | None | lrzip (Long Range ZIP) | 100.00 MB (100.0%) | 100.01 MB (100.0%) | 94.6 MB/s | 109.0 MB/s | **1.2x** | 364.1 MB/s | 526.0 MB/s | **1.4x** | - |
| High-Entropy Payload (100MB) | AAR | 1 | None | Apple aa (Apple Archive CLI) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 36588.7 MB/s | 2313.6 MB/s | **0.1x** | 35644.8 MB/s | 3120.5 MB/s | **0.1x** | - |
| High-Entropy Payload (100MB) | AAR | 6 | None | Apple aa (Apple Archive CLI) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 37655.3 MB/s | 2333.1 MB/s | **0.1x** | 40284.7 MB/s | 3087.2 MB/s | **0.1x** | - |
| High-Entropy Payload (100MB) | WIM | 1 | None | wimlib-imagex CLI | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 19349.2 MB/s | 5761.4 MB/s | **0.3x** | 23702.3 MB/s | 9727.4 MB/s | **0.4x** | - |
| High-Entropy Payload (100MB) | WIM | 1 | AES-256 | wimlib-imagex CLI | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 19019.7 MB/s | 5836.2 MB/s | **0.3x** | 22952.2 MB/s | 9717.3 MB/s | **0.4x** | - |
| High-Entropy Payload (100MB) | WIM | 6 | None | wimlib-imagex CLI | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 18643.7 MB/s | 5801.7 MB/s | **0.3x** | 22622.7 MB/s | 9752.9 MB/s | **0.4x** | - |
| High-Entropy Payload (100MB) | WIM | 6 | AES-256 | wimlib-imagex CLI | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 19496.7 MB/s | 5810.0 MB/s | **0.3x** | 22817.4 MB/s | 9475.5 MB/s | **0.4x** | - |
| High-Entropy Payload (100MB) | DMG | 1 | None | Apple hdiutil (macOS Native) | 101.96 MB (102.0%) | 100.35 MB (100.4%) | 16.6 MB/s | 3342.8 MB/s | **201.7x** | 58.7 MB/s | 6410.7 MB/s | **109.3x** | - |
| High-Entropy Payload (100MB) | DMG | 1 | AES-256 | Apple hdiutil (macOS Native) | 100.35 MB (100.4%) | 100.35 MB (100.4%) | 24.8 MB/s | 3634.0 MB/s | **146.3x** | 3033.4 MB/s | 6470.0 MB/s | **2.1x** | - |
| High-Entropy Payload (100MB) | DMG | 6 | None | Apple hdiutil (macOS Native) | 101.96 MB (102.0%) | 100.35 MB (100.4%) | 16.6 MB/s | 3483.2 MB/s | **210.1x** | 37.8 MB/s | 6441.3 MB/s | **170.4x** | - |
| High-Entropy Payload (100MB) | DMG | 6 | AES-256 | Apple hdiutil (macOS Native) | 101.96 MB (102.0%) | 100.35 MB (100.4%) | 16.6 MB/s | 3497.6 MB/s | **211.1x** | 35.4 MB/s | 6568.3 MB/s | **185.5x** | - |
| 500MB Large Dataset (500MB) | 7Z | 1 | None | 7-Zip 7zz CLI (ARM64) | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 4846.3 MB/s | 5163.5 MB/s | **1.1x** | 4532.4 MB/s | 8964.6 MB/s | **2.0x** | - |
| 500MB Large Dataset (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI (ARM64) | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 4754.2 MB/s | 4816.2 MB/s | **1.0x** | 5212.4 MB/s | 8117.8 MB/s | **1.6x** | - |
| 500MB Large Dataset (500MB) | 7Z | 6 | None | 7-Zip 7zz CLI (ARM64) | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 661.6 MB/s | 4764.6 MB/s | **7.2x** | 3756.4 MB/s | 9551.7 MB/s | **2.5x** | - |
| 500MB Large Dataset (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI (ARM64) | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 654.6 MB/s | 4866.8 MB/s | **7.4x** | 3664.6 MB/s | 8334.4 MB/s | **2.3x** | - |
| 500MB Large Dataset (500MB) | ZIP | 1 | None | 7-Zip 7zz CLI (ARM64) | 0.59 MB (0.1%) | 2.04 MB (0.4%) | 992.9 MB/s | 6674.3 MB/s | **6.7x** | 1659.0 MB/s | 9761.2 MB/s | **5.9x** | - |
| 500MB Large Dataset (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz CLI (ARM64) | 0.59 MB (0.1%) | 2.04 MB (0.4%) | 847.9 MB/s | 6631.3 MB/s | **7.8x** | 1644.2 MB/s | 9550.2 MB/s | **5.8x** | - |
| 500MB Large Dataset (500MB) | ZIP | 6 | None | Apple ditto (Native macOS) | 0.49 MB (0.1%) | 0.48 MB (0.1%) | 588.1 MB/s | 111.8 MB/s | **0.2x** | 3641.1 MB/s | 11353.6 MB/s | **3.1x** | - |
| 500MB Large Dataset (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz CLI (ARM64) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 91.5 MB/s | 1300.2 MB/s | **14.2x** | 1602.1 MB/s | 10832.4 MB/s | **6.8x** | - |
| 500MB Large Dataset (500MB) | TAR.ZST | 1 | None | Zstandard zstd CLI (-T0 All Cores) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 4120.3 MB/s | 21069.4 MB/s | **5.1x** | 1858.5 MB/s | 4637.3 MB/s | **2.5x** | - |
| 500MB Large Dataset (500MB) | TAR.ZST | 6 | None | Zstandard zstd CLI (-T0 All Cores) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 3801.8 MB/s | 19099.6 MB/s | **5.0x** | 1931.4 MB/s | 5052.7 MB/s | **2.6x** | - |
| 500MB Large Dataset (500MB) | TAR.GZ | 1 | None | Parallel pigz (Multi-threaded GZIP) | 2.25 MB (0.5%) | 2.05 MB (0.4%) | 1962.5 MB/s | 15249.9 MB/s | **7.8x** | 1678.9 MB/s | 5885.3 MB/s | **3.5x** | - |
| 500MB Large Dataset (500MB) | TAR.GZ | 6 | None | Parallel pigz (Multi-threaded GZIP) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2004.3 MB/s | 12269.7 MB/s | **6.1x** | 1726.8 MB/s | 2953.2 MB/s | **1.7x** | - |
| 500MB Large Dataset (500MB) | TAR.BZ2 | 1 | None | pbzip2 (All Cores) | 0.03 MB (0.0%) | 0.02 MB (0.0%) | 2330.4 MB/s | 2667.2 MB/s | **1.1x** | 1873.5 MB/s | 2049.0 MB/s | **1.1x** | - |
| 500MB Large Dataset (500MB) | TAR.BZ2 | 6 | None | pbzip2 (All Cores) | 0.03 MB (0.0%) | 0.02 MB (0.0%) | 2299.9 MB/s | 2694.7 MB/s | **1.2x** | 1870.6 MB/s | 2047.3 MB/s | **1.1x** | - |
| 500MB Large Dataset (500MB) | TAR.XZ | 1 | None | pixz (All Cores) | 0.10 MB (0.0%) | 0.14 MB (0.0%) | 3069.9 MB/s | 4350.1 MB/s | **1.4x** | 1852.9 MB/s | 1031.9 MB/s | **0.6x** | - |
| 500MB Large Dataset (500MB) | TAR.XZ | 6 | None | pixz (All Cores) | 0.08 MB (0.0%) | 0.14 MB (0.0%) | 1637.9 MB/s | 2661.7 MB/s | **1.6x** | 1797.2 MB/s | 1019.4 MB/s | **0.6x** | - |
| 500MB Large Dataset (500MB) | TAR | 1 | None | 7-Zip 7zz CLI (ARM64) | 500.00 MB (100.0%) | 500.00 MB (100.0%) | 6232.2 MB/s | 5751.9 MB/s | **0.9x** | 5556.0 MB/s | 8687.0 MB/s | **1.6x** | - |
| 500MB Large Dataset (500MB) | TAR | 6 | None | 7-Zip 7zz CLI (ARM64) | 500.00 MB (100.0%) | 500.00 MB (100.0%) | 5838.4 MB/s | 5779.7 MB/s | **1.0x** | 7033.3 MB/s | 8495.5 MB/s | **1.2x** | - |
| 500MB Large Dataset (500MB) | LZIP | 1 | None | plzip (Parallel Lzip) | 0.10 MB (0.0%) | 0.14 MB (0.0%) | 1399.3 MB/s | 4345.2 MB/s | **3.1x** | 1051.7 MB/s | 1007.5 MB/s | **1.0x** | - |
| 500MB Large Dataset (500MB) | LZIP | 6 | None | plzip (Parallel Lzip) | 0.07 MB (0.0%) | 0.14 MB (0.0%) | 665.0 MB/s | 2617.7 MB/s | **3.9x** | 1390.7 MB/s | 1018.2 MB/s | **0.7x** | - |
| 500MB Large Dataset (500MB) | LZ4 | 1 | None | lz4 CLI (C11 Native) | 1.96 MB (0.4%) | 2.07 MB (0.4%) | 2424.6 MB/s | 15474.7 MB/s | **6.4x** | 1670.5 MB/s | 2506.5 MB/s | **1.5x** | - |
| 500MB Large Dataset (500MB) | LZ4 | 6 | None | lz4 CLI (C11 Native) | 1.96 MB (0.4%) | 2.07 MB (0.4%) | 2401.5 MB/s | 15627.3 MB/s | **6.5x** | 1333.0 MB/s | 1967.5 MB/s | **1.5x** | - |
| 500MB Large Dataset (500MB) | BROTLI | 1 | None | Google Brotli CLI | 0.09 MB (0.0%) | 0.00 MB (0.0%) | 1822.7 MB/s | 1115.4 MB/s | **0.6x** | 810.0 MB/s | 1524.6 MB/s | **1.9x** | - |
| 500MB Large Dataset (500MB) | BROTLI | 6 | None | Google Brotli CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 949.1 MB/s | 1052.1 MB/s | **1.1x** | 971.6 MB/s | 1489.9 MB/s | **1.5x** | - |
| 500MB Large Dataset (500MB) | LRZIP | 1 | None | lrzip (Long Range ZIP) | 2.22 MB (0.4%) | 0.14 MB (0.0%) | 198.3 MB/s | 4156.6 MB/s | **21.0x** | 382.5 MB/s | 1002.9 MB/s | **2.6x** | - |
| 500MB Large Dataset (500MB) | LRZIP | 6 | None | lrzip (Long Range ZIP) | 2.22 MB (0.4%) | 0.14 MB (0.0%) | 219.8 MB/s | 2500.1 MB/s | **11.4x** | 382.8 MB/s | 913.2 MB/s | **2.4x** | - |
| 500MB Large Dataset (500MB) | AAR | 1 | None | Apple aa (Apple Archive CLI) | 0.37 MB (0.1%) | 0.37 MB (0.1%) | 137146.0 MB/s | 3181.3 MB/s | **0.0x** | 118936.7 MB/s | 6760.4 MB/s | **0.1x** | - |
| 500MB Large Dataset (500MB) | AAR | 6 | None | Apple aa (Apple Archive CLI) | 0.37 MB (0.1%) | 0.37 MB (0.1%) | 219599.2 MB/s | 3057.8 MB/s | **0.0x** | 183178.1 MB/s | 6507.1 MB/s | **0.0x** | - |
| 500MB Large Dataset (500MB) | WIM | 1 | None | wimlib-imagex CLI | 500.00 MB (100.0%) | 500.00 MB (100.0%) | 100586.8 MB/s | 5839.6 MB/s | **0.1x** | 113942.8 MB/s | 9981.8 MB/s | **0.1x** | - |
| 500MB Large Dataset (500MB) | WIM | 1 | AES-256 | wimlib-imagex CLI | 500.00 MB (100.0%) | 500.00 MB (100.0%) | 91029.8 MB/s | 6035.8 MB/s | **0.1x** | 116627.1 MB/s | 10273.8 MB/s | **0.1x** | - |
| 500MB Large Dataset (500MB) | WIM | 6 | None | wimlib-imagex CLI | 500.00 MB (100.0%) | 500.00 MB (100.0%) | 95748.8 MB/s | 5730.2 MB/s | **0.1x** | 120320.1 MB/s | 9871.4 MB/s | **0.1x** | - |
| 500MB Large Dataset (500MB) | WIM | 6 | AES-256 | wimlib-imagex CLI | 500.00 MB (100.0%) | 500.00 MB (100.0%) | 96083.0 MB/s | 5897.1 MB/s | **0.1x** | 110523.7 MB/s | 10173.4 MB/s | **0.1x** | - |
| 500MB Large Dataset (500MB) | DMG | 1 | None | Apple hdiutil (macOS Native) | 0.06 MB (0.0%) | 500.35 MB (100.1%) | 71.0 MB/s | 3139.7 MB/s | **44.2x** | 71.0 MB/s | 5257.4 MB/s | **74.1x** | - |
| 500MB Large Dataset (500MB) | DMG | 1 | AES-256 | Apple hdiutil (macOS Native) | 0.06 MB (0.0%) | 500.35 MB (100.1%) | 82.8 MB/s | 3192.4 MB/s | **38.5x** | 380.7 MB/s | 5032.9 MB/s | **13.2x** | - |
| 500MB Large Dataset (500MB) | DMG | 6 | None | Apple hdiutil (macOS Native) | 0.06 MB (0.0%) | 500.35 MB (100.1%) | 99.5 MB/s | 3663.8 MB/s | **36.8x** | 148.4 MB/s | 7147.5 MB/s | **48.2x** | - |
| 500MB Large Dataset (500MB) | DMG | 6 | AES-256 | Apple hdiutil (macOS Native) | 0.06 MB (0.0%) | 500.35 MB (100.1%) | 82.9 MB/s | 3795.8 MB/s | **45.8x** | 212.3 MB/s | 6560.2 MB/s | **30.9x** | - |
