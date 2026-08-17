import SwiftUI
import TTZipCore

public struct CompressionProInspectorPanel: View {
    @Binding public var isProInspectorPresented: Bool
    @Binding public var cpuThreadsOption: String
    @Binding public var dictionarySizeMB: Int
    @Binding public var compressionAlgorithm: String
    @Binding public var zipEncryptionMethod: String
    @Binding public var zipEncodingUTF8: Bool
    @Binding public var zstdLevel: Int
    @Binding public var zstdEnableLDM: Bool
    @Binding public var preservePosixAttributes: Bool
    @Binding public var enableSolidArchive: Bool
    @Binding public var encryptFileNames: Bool
    @Binding public var enableEncryption: Bool
    @Binding public var isPasswordVaultPresented: Bool
    
    public let selectedFormat: ArchiveCompressionFormat
    public let cachedTotalCores: Int
    public let onShowMatrix: () -> Void
    
    public init(
        isProInspectorPresented: Binding<Bool>,
        cpuThreadsOption: Binding<String>,
        dictionarySizeMB: Binding<Int>,
        compressionAlgorithm: Binding<String>,
        zipEncryptionMethod: Binding<String>,
        zipEncodingUTF8: Binding<Bool>,
        zstdLevel: Binding<Int>,
        zstdEnableLDM: Binding<Bool>,
        preservePosixAttributes: Binding<Bool>,
        enableSolidArchive: Binding<Bool>,
        encryptFileNames: Binding<Bool>,
        enableEncryption: Binding<Bool>,
        isPasswordVaultPresented: Binding<Bool>,
        selectedFormat: ArchiveCompressionFormat,
        cachedTotalCores: Int,
        onShowMatrix: @escaping () -> Void
    ) {
        self._isProInspectorPresented = isProInspectorPresented
        self._cpuThreadsOption = cpuThreadsOption
        self._dictionarySizeMB = dictionarySizeMB
        self._compressionAlgorithm = compressionAlgorithm
        self._zipEncryptionMethod = zipEncryptionMethod
        self._zipEncodingUTF8 = zipEncodingUTF8
        self._zstdLevel = zstdLevel
        self._zstdEnableLDM = zstdEnableLDM
        self._preservePosixAttributes = preservePosixAttributes
        self._enableSolidArchive = enableSolidArchive
        self._encryptFileNames = encryptFileNames
        self._enableEncryption = enableEncryption
        self._isPasswordVaultPresented = isPasswordVaultPresented
        self.selectedFormat = selectedFormat
        self.cachedTotalCores = cachedTotalCores
        self.onShowMatrix = onShowMatrix
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Apple Silicon 硬件加速", systemImage: "cpu.fill")
                    .font(.system(size: 13, weight: .bold, design: .serif))
                    .foregroundStyle(TTZipTheme.kintsugiGold)
                Spacer()
                Button(action: { withAnimation { isProInspectorPresented = false } }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("并行 CPU 线程分配")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Picker("", selection: $cpuThreadsOption) {
                    Text("全核满载 (\(cachedTotalCores) 线程 - 最佳速度)").tag("全核")
                    Text("半核负载 (\(max(1, cachedTotalCores / 2)) 线程)").tag("半核")
                    Text("单线程 (\(1) 线程 - 后台低热量)").tag("单核")
                }
                .pickerStyle(.segmented)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Label("压缩策略与安全机制", systemImage: "lock.shield.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(TTZipTheme.bambooGreen)
                
                Toggle("启用固实压缩包 (Solid Archive)", isOn: $enableSolidArchive)
                    .disabled(selectedFormat != .sevenZip)
                    .help("固实压缩可将大量同类小文件合并计算，显著提升压缩比")
                
                Toggle("加密压缩包文件列表与文件名", isOn: $encryptFileNames)
                    .disabled(!enableEncryption || selectedFormat != .sevenZip)
                    .help("开启后，未经密码解锁无法查看包内文件名与目录树结构")
                
                Toggle("高强度 AES-256 位加密", isOn: $enableEncryption)
                
                if enableEncryption {
                    Button(action: { isPasswordVaultPresented = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "key.fill")
                            Text("打开密码库...")
                        }
                        .font(.caption)
                        .foregroundStyle(TTZipTheme.kintsugiGold)
                    }
                    .buttonStyle(.plain)
                }
            }
            .tint(TTZipTheme.bambooGreen)
            .font(.caption)
            
            Divider()
            
            AlgorithmGuidanceCardView(
                algoInfo: formatGuidanceInfo(selectedFormat),
                onShowMatrix: onShowMatrix
            )
        }
        .padding(14)
        .background(TTZipTheme.subtleFill)
        .clipShape(RoundedRectangle(cornerRadius: TTZipTheme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TTZipTheme.Radius.md, style: .continuous)
                .strokeBorder(TTZipTheme.hairlineBorder, lineWidth: 0.8)
        )
    }
    
    private func formatGuidanceInfo(_ format: ArchiveCompressionFormat) -> (icon: String, color: Color, title: String, desc: String) {
        switch format {
        case .sevenZip:
            return ("sparkles", .blue, "7-Zip (LZMA2) 现代标准", "极限空间压缩比，推荐用于大文档、工程代码库备份")
        case .zip:
            return ("doc.zipper", .purple, "ZIP 经典跨平台", "最高全平台兼容性，完美适配 Windows 与移动端解压")
        case .zst:
            return ("bolt.circle.fill", .orange, "Zstandard (.zst) 极速引擎", "RFC 8878 标准物理数据帧，多 GB/s 超高速全核并发解压")
        case .tarZst:
            return ("bolt.fill", .orange, "TAR.ZST Meta 极速引擎", "支持多 GB/s 超高速多核并行解包与数据流吞吐")
        case .tarGz, .gz:
            return ("terminal.fill", .green, "TAR.GZ Linux/DevOps", "标准 Unix 服务器发布与开源项目代码镜像格式")
        case .tar:
            return ("folder.fill", .brown, "TAR POSIX 零拷贝", "无压缩极速归档打包，满载磁盘物理 I/O 带宽")
        case .bz2, .tarBz2:
            return ("shippingbox.fill", .indigo, "BZIP2 传统高压", "pbzip2 多块并行拆分算法，传统 UNIX 高度无损归档")
        case .xz, .tarXz:
            return ("cpu.fill", .cyan, "XZ 源码极限高压", "Parallel LZMA2 线程池分片，开源软件发布与镜像必备")
        case .lzip:
            return ("shield.checkerboard", .pink, "LZIP 安全容错归档", "基于 32-bit CRC32 LZMA 并行切块，高容错数据备份")
        case .lz4:
            return ("bolt.horizontal.fill", .teal, "LZ4 Sub-millisecond 帧", "极速毫秒级流体压解，吞吐突破数 GB/s 物理极限")
        case .brotli:
            return ("globe", .orange, "BROTLI 网页资源优化", "Google Brotli 算法，针对 Web 文本与前端静态资源优化")
        case .lrzip:
            return ("slider.horizontal.below.square.filled.and.arrow.between.any.capsule", .mint, "LRZIP 超长距离预处理", " Gigabyte-window 重复串预处理，海量大文件压缩率第一")
        case .aar:
            return ("apple.logo", .red, "AAR Apple Native 归档", "100% macOS Native Apple Silicon 硬件加速 (LZFSE/PBZX)")
        case .snappy:
            return ("paperplane.fill", .yellow, "SNAPPY Framed 内存流", "Google Snappy 高吞吐无延迟流式压缩引擎")
        case .wim:
            return ("window.vertical.closed", .blue, "WIM Windows 镜像", "Windows 部署镜像与系统安装文件封装规范")
        case .dmg:
            return ("disc.fill", .gray, "DMG Apple 磁盘映像", "macOS 标准 APFS/UDZO 可挂载虚拟磁盘格式")
        case .iso:
            return ("opticaldisc.fill", .purple, "ISO 光盘镜像", "ISO9660 / Joliet / UDF 通用复合光盘映像")
        }
    }
}
