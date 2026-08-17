import SwiftUI
import TTZipCore

/// 新建压缩工程 高级专业配置与硬件调度组件 (竹绿主题与高透卡片版)
public struct CompressAdvancedOptionsSectionView: View {
    @Binding public var cpuThreadsOption: String
    @Binding public var splitVolumeOption: Int64?
    @Binding public var isCustomVolumeSelected: Bool
    @Binding public var customVolumeValueString: String
    @Binding public var customVolumeUnit: String
    @Binding public var enableEncryption: Bool
    @Binding public var password: String
    @Binding public var enableSolidArchive: Bool
    @Binding public var encryptFileNames: Bool
    @Binding public var skipMacJunk: Bool
    @Binding public var createSeparateArchives: Bool
    @Binding public var deleteSourceAfterCompress: Bool
    @Binding public var openFinderAfterCompress: Bool
    
    public let selectedFormat: ArchiveCompressionFormat
    public let cachedTotalCores: Int
    public let onOpenPasswordVault: () -> Void
    public let onShowMatrix: () -> Void
    
    public init(
        cpuThreadsOption: Binding<String>,
        splitVolumeOption: Binding<Int64?>,
        isCustomVolumeSelected: Binding<Bool>,
        customVolumeValueString: Binding<String>,
        customVolumeUnit: Binding<String>,
        enableEncryption: Binding<Bool>,
        password: Binding<String>,
        enableSolidArchive: Binding<Bool>,
        encryptFileNames: Binding<Bool>,
        skipMacJunk: Binding<Bool>,
        createSeparateArchives: Binding<Bool>,
        deleteSourceAfterCompress: Binding<Bool>,
        openFinderAfterCompress: Binding<Bool>,
        selectedFormat: ArchiveCompressionFormat,
        cachedTotalCores: Int,
        onOpenPasswordVault: @escaping () -> Void,
        onShowMatrix: @escaping () -> Void
    ) {
        self._cpuThreadsOption = cpuThreadsOption
        self._splitVolumeOption = splitVolumeOption
        self._isCustomVolumeSelected = isCustomVolumeSelected
        self._customVolumeValueString = customVolumeValueString
        self._customVolumeUnit = customVolumeUnit
        self._enableEncryption = enableEncryption
        self._password = password
        self._enableSolidArchive = enableSolidArchive
        self._encryptFileNames = encryptFileNames
        self._skipMacJunk = skipMacJunk
        self._createSeparateArchives = createSeparateArchives
        self._deleteSourceAfterCompress = deleteSourceAfterCompress
        self._openFinderAfterCompress = openFinderAfterCompress
        self.selectedFormat = selectedFormat
        self.cachedTotalCores = cachedTotalCores
        self.onOpenPasswordVault = onOpenPasswordVault
        self.onShowMatrix = onShowMatrix
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Apple Silicon 硬件加速与高级引擎配置", systemImage: "cpu.fill")
                    .font(.system(size: 13, weight: .bold, design: .serif))
                    .foregroundStyle(TTZipTheme.kintsugiGold)
                Spacer()
            }
            
            // 算法指导提示卡
            AlgorithmGuidanceCardView(
                algoInfo: formatGuidanceInfo(selectedFormat),
                onShowMatrix: onShowMatrix
            )
            
            // CPU 线程调度 (支持竹绿 Tint)
            VStack(alignment: .leading, spacing: 6) {
                Text("并行 CPU 线程分配")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Picker("", selection: $cpuThreadsOption) {
                    Text("全核满载 (\(cachedTotalCores) 线程 - 最佳速度)").tag("全核")
                    Text("半核负载 (\(max(1, cachedTotalCores / 2)) 线程)").tag("半核")
                    Text("单线程 (\(1) 线程 - 后台低热量)").tag("单核")
                }
                .pickerStyle(.segmented)
                .tint(TTZipTheme.bambooGreen)
            }
            
            // 分卷限制选择
            VStack(alignment: .leading, spacing: 6) {
                Text("分卷大小限制 (Split Volume)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    volumeOptionTile(size: nil, name: "不分卷")
                    volumeOptionTile(size: 700 * 1024 * 1024, name: "CD (700MB)")
                    volumeOptionTile(size: 4700 * 1024 * 1024, name: "DVD (4.7GB)")
                    volumeOptionTile(size: 4000 * 1024 * 1024, name: "FAT32 (4GB)")
                    volumeOptionTile(size: -1, name: "自定义 MB")
                }
                
                if isCustomVolumeSelected {
                    HStack(spacing: 6) {
                        TextField("数值", text: $customVolumeValueString)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11.5))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.035))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8))
                            .frame(width: 100)
                        
                        Picker("", selection: $customVolumeUnit) {
                            Text("MB").tag("MB")
                            Text("GB").tag("GB")
                        }
                        .pickerStyle(.segmented)
                        .tint(TTZipTheme.bambooGreen)
                        .frame(width: 100)
                    }
                    .padding(.top, 4)
                }
            }
            
            Divider()
            
            // 加密与口令配置 (全量应用竹绿 .tint)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Toggle("启用高强度 AES-256 位加密", isOn: $enableEncryption)
                        .font(.system(size: 11.5, weight: .bold))
                        .tint(TTZipTheme.bambooGreen)
                    
                    Spacer()
                    
                    Button(action: onOpenPasswordVault) {
                        HStack(spacing: 4) {
                            Image(systemName: "key.fill")
                            Text("🔑 从密码库选择口令...")
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(TTZipTheme.kintsugiGold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(TTZipTheme.kintsugiGold.opacity(0.14))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                
                if enableEncryption {
                    TTSecureTextField("设置加密解压密码", text: $password)
                        .font(.system(size: 12))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.035))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8))
                }
                
                Toggle("固实压缩包 (Solid Archive - 提高多小文件压缩率)", isOn: $enableSolidArchive)
                    .disabled(selectedFormat != .sevenZip)
                    .tint(TTZipTheme.bambooGreen)
                
                Toggle("加密文件名与目录树结构", isOn: $encryptFileNames)
                    .disabled(!enableEncryption || selectedFormat != .sevenZip)
                    .tint(TTZipTheme.bambooGreen)
            }
            .font(.system(size: 11))
            
            Divider()
            
            // 清理与自动化 Toggle 组 (双列网格高保真配图与竹绿 .tint)
            VStack(alignment: .leading, spacing: 8) {
                Text("系统清理与自动化策略")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    Toggle("过滤 macOS 垃圾 (.DS_Store / __MACOSX)", isOn: $skipMacJunk)
                        .tint(TTZipTheme.bambooGreen)
                    
                    Toggle("选中项目独立单独打包", isOn: $createSeparateArchives)
                        .tint(TTZipTheme.bambooGreen)
                    
                    Toggle("压缩成功后移至废纸篓", isOn: $deleteSourceAfterCompress)
                        .tint(TTZipTheme.bambooGreen)
                    
                    Toggle("完成后在 Finder 中高亮显示", isOn: $openFinderAfterCompress)
                        .tint(TTZipTheme.bambooGreen)
                }
                .font(.system(size: 11))
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }
    
    private func volumeOptionTile(size: Int64?, name: String) -> some View {
        let isSelected: Bool
        if size == -1 {
            isSelected = isCustomVolumeSelected
        } else {
            isSelected = !isCustomVolumeSelected && splitVolumeOption == size
        }
        
        return Button(action: {
            if size == -1 {
                isCustomVolumeSelected = true
                calculateCustomVolume()
            } else {
                isCustomVolumeSelected = false
                splitVolumeOption = size
            }
        }) {
            Text(name)
                .font(.system(size: 10.5, weight: isSelected ? .bold : .regular))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(isSelected ? TTZipTheme.bambooGreen.opacity(0.14) : Color.primary.opacity(0.03))
                .foregroundStyle(isSelected ? TTZipTheme.bambooGreen : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(isSelected ? TTZipTheme.bambooGreen.opacity(0.4) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    private func calculateCustomVolume() {
        guard let val = Int64(customVolumeValueString) else {
            splitVolumeOption = nil
            return
        }
        let multiplier: Int64 = (customVolumeUnit == "GB") ? 1024 * 1024 * 1024 : 1024 * 1024
        splitVolumeOption = val * multiplier
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
            return ("slider.horizontal.below.square.filled.and.arrow.between.any.capsule", .mint, "LRZIP 超长距离预处理", "Gigabyte-window 重复串预处理，海量大文件压缩率第一")
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
