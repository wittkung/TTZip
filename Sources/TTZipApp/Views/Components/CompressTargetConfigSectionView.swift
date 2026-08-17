import SwiftUI
import TTZipCore

/// 新建压缩工程 目标基础配置区组件 (竹绿主题高透卡片版)
public struct CompressTargetConfigSectionView: View {
    @Binding public var outputName: String
    @Binding public var targetDirectory: String
    @Binding public var selectedFormat: ArchiveCompressionFormat
    @Binding public var compressionLevel: ArchiveCompressionLevel
    public let onPickDirectory: () -> Void
    
    public init(
        outputName: Binding<String>,
        targetDirectory: Binding<String>,
        selectedFormat: Binding<ArchiveCompressionFormat>,
        compressionLevel: Binding<ArchiveCompressionLevel>,
        onPickDirectory: @escaping () -> Void
    ) {
        self._outputName = outputName
        self._targetDirectory = targetDirectory
        self._selectedFormat = selectedFormat
        self._compressionLevel = compressionLevel
        self.onPickDirectory = onPickDirectory
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("压缩包目标配置", systemImage: "gearshape.fill")
                .font(.system(size: 13, weight: .bold, design: .serif))
                .foregroundStyle(TTZipTheme.bambooGreen)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text("输出文件名")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 75, alignment: .trailing)
                    
                    TextField("输出文件名", text: $outputName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.035))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8)
                        )
                }
                
                HStack(spacing: 12) {
                    Text("保存位置")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 75, alignment: .trailing)
                    
                    HStack(spacing: 6) {
                        TextField("目标文件夹路径", text: $targetDirectory)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11.5))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.primary.opacity(0.035))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8)
                            )
                        
                        Button("浏览...") { onPickDirectory() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            }
            
            HStack(spacing: 12) {
                Text("封装格式")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 75, alignment: .trailing)
                
                HStack(spacing: 8) {
                    formatOptionTile(format: .sevenZip, name: "7-Zip", ext: ".7z (推荐)")
                    formatOptionTile(format: .zip, name: "ZIP", ext: ".zip (通用)")
                    formatOptionTile(format: .tarZst, name: "TAR.ZST", ext: ".zst (极速)")
                    formatOptionTile(format: .tarGz, name: "TAR.GZ", ext: ".tar.gz (Linux)")
                }
            }
            
            HStack(spacing: 12) {
                Text("压缩级别")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 75, alignment: .trailing)
                
                HStack(spacing: 6) {
                    levelOptionTile(level: .store, name: "仅存储 (0x)")
                    levelOptionTile(level: .fast, name: "快速 (1x)")
                    levelOptionTile(level: .normal, name: "标准 (5x)")
                    levelOptionTile(level: .ultra, name: "极限 (9x)")
                }
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
    
    private func formatOptionTile(format: ArchiveCompressionFormat, name: String, ext: String) -> some View {
        let isSelected = selectedFormat == format
        return Button(action: { selectedFormat = format }) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 11, weight: .bold))
                Text(ext).font(.system(size: 9.5)).foregroundStyle(isSelected ? TTZipTheme.bambooGreen : Color.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? TTZipTheme.bambooGreen.opacity(0.14) : Color.primary.opacity(0.03))
            .foregroundStyle(isSelected ? TTZipTheme.bambooGreen : Color.primary)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? TTZipTheme.bambooGreen.opacity(0.45) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func levelOptionTile(level: ArchiveCompressionLevel, name: String) -> some View {
        let isSelected = compressionLevel == level
        return Button(action: { compressionLevel = level }) {
            Text(name)
                .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(isSelected ? TTZipTheme.bambooGreen.opacity(0.14) : Color.primary.opacity(0.03))
                .foregroundStyle(isSelected ? TTZipTheme.bambooGreen : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(isSelected ? TTZipTheme.bambooGreen.opacity(0.4) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
