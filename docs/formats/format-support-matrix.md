# TTZip Format Support Matrix & Technical Specifications

TTZip provides full-matrix archiving, compression, decompression, and live file tree penetration across **16 modern and legacy archive formats**.

---

## 1. Full-Matrix Supported Formats (16 Formats)

All 16 formats below are **100% natively supported for compression creation, decompression, and live file tree penetration** with in-process C static engines:

| Format | Extensions | Primary In-Process C Engine | Supported Codecs / Features | Compression Levels | Password Encryption | Split Volumes |
| :--- | :--- | :--- | :--- | :---: | :---: | :---: |
| **ZIP** | `.zip` | `libdeflate` + Native Parallel C | DEFLATE, Store, BZIP2, LZMA | 0 (Store) ~ 9 (Ultra) | ZipCrypto, AES-256 | ✅ (`.zip.001`, `.z01`) |
| **7Z** | `.7z`, `.cb7` | `LZMA SDK` / `Fast-LZMA2` | LZMA, LZMA2, PPMd, BCJ/BCJ2, Solid | 1 (Fast) ~ 9 (Ultra) | AES-256 (Header + Data) | ✅ (`.7z.001`) |
| **TAR** | `.tar` | Native POSIX Direct I/O | Uncompressed POSIX ustar / pax | 0 (Store) | ❌ | ✅ (`.tar.001`) |
| **TAR.ZST** | `.tar.zst`, `.tzst`, `.zst` | `libzstd` | Zstandard (v1.5+) + Long Distance Matching | 1 (Fast) ~ 22 (Ultra) | ❌ | ✅ |
| **TAR.GZ** | `.tar.gz`, `.tgz`, `.gz` | `libdeflate` + Native C | GZIP (RFC 1952) Deflate | 1 ~ 12 | ❌ | ✅ |
| **TAR.BZ2** | `.tar.bz2`, `.tbz2`, `.bz2`| `libbz2` + Native C | BZIP2 Block Compression | 1 ~ 9 | ❌ | ✅ |
| **TAR.XZ** | `.tar.xz`, `.txz`, `.xz` | `liblzma` | LZMA2 + BCJ Filter | 0 ~ 9e | ❌ | ✅ |
| **LZ4** | `.lz4`, `.tar.lz4` | `liblz4` | LZ4 Frame / Block Fast Pipeline | Fast 1 ~ 9, HC 1 ~ 12 | ❌ | ❌ |
| **LZIP** | `.lz`, `.tar.lz`, `.lzip` | `liblzma` (Lzip) | LZMA Stream Engine | 0 ~ 9 | ❌ | ❌ |
| **LRZIP** | `.lrz`, `.tar.lrz`, `.lrzip`| Native C Pipe | Long Range rzip + LZMA / ZSTD | 1 ~ 9 | ❌ | ❌ |
| **BROTLI** | `.br`, `.tar.br`, `.brotli` | `brotli` | Brotli (RFC 7932) Web Stream | 0 ~ 11 | ❌ | ❌ |
| **SNAPPY** | `.sz`, `.tar.sz`, `.snappy`| Native Snappy | Snappy Framing Stream | Fast Default | ❌ | ❌ |
| **AAR** | `.aar` | Native Apple Archive | LZFSE, LZ4, ZSTD, LZMA | Standard Levels | ❌ | ❌ |
| **DMG** | `.dmg` | `libarchive` + HFS+/APFS | UDIF (zlib, bz2, lzma, raw) | 0 (Packaging / Imaging) | Encrypted DMG | ❌ |
| **ISO** | `.iso` | `libarchive` | ISO-9660, Joliet, RockRidge | 0 (Packaging / Imaging) | ❌ | ❌ |
| **WIM** | `.wim` | `libarchive` | XPRESS, LZX, LZMS | 0 (Store) ~ 9 (Ultra) | ✅ (WIM Encrypted) | ✅ (`.swm`) |

---

## 2. Legacy & Extraction / Penetration Formats

For proprietary and legacy formats, TTZip provides **100% in-process decompression, deep file tree penetration, and space-bar QuickLook preview**:

| Format | Extensions | Extraction & Penetration Engine | Supported Features |
| :--- | :--- | :--- | :--- |
| **RAR / CBR** | `.rar`, `.cbr` | `libarchive` (UnRAR C) | RAR v1.5 ~ RAR v5, Solid archives, AES decryption |
| **ZipX** | `.zipx` | Native ZipX Stream Decoder | PPMd, XZ, WavPack, BZIP2 inside Zip container |
| **CAB** | `.cab` | `libarchive` Cabinet Engine | Microsoft Cabinet (MSZIP, Quantum, LZX) |
| **Split Volumes** | `.001`, `.002`, ... | In-Process Multi-Stream Stitcher | Continuous streaming across multi-part archive splits |
