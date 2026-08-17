import SwiftUI
import TTZipCore

public struct PresetEditorCardView: View {
    @Binding public var editorFormat: ArchiveCompressionFormat
    @Binding public var editorLevel: ArchiveCompressionLevel
    @Binding public var editorSplitVolumeOption: Int64?
    @Binding public var editorSkipMacJunk: Bool
    @Binding public var editorSkipGitDirectory: Bool
    
    public init(
        editorFormat: Binding<ArchiveCompressionFormat>,
        editorLevel: Binding<ArchiveCompressionLevel>,
        editorSplitVolumeOption: Binding<Int64?>,
        editorSkipMacJunk: Binding<Bool>,
        editorSkipGitDirectory: Binding<Bool>
    ) {
        self._editorFormat = editorFormat
        self._editorLevel = editorLevel
        self._editorSplitVolumeOption = editorSplitVolumeOption
        self._editorSkipMacJunk = editorSkipMacJunk
        self._editorSkipGitDirectory = editorSkipGitDirectory
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                Label("分卷切割规格 (Volume Splitting)", systemImage: "scissors")
                    .font(.system(size: 13, weight: .bold, design: .serif))
                    .foregroundStyle(TTZipTheme.kintsugiGold)
                
                HStack(spacing: 12) {
                    Text("分卷大小")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 75, alignment: .trailing)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            splitVolumeTile(bytes: nil, label: "不分卷")
                            splitVolumeTile(bytes: 25 * 1024 * 1024, label: "25 MB (邮件限额)")
                            splitVolumeTile(bytes: 100 * 1024 * 1024, label: "100 MB (网盘限额)")
                            splitVolumeTile(bytes: 4 * 1024 * 1024 * 1024, label: "4 GB (FAT32)")
                            splitVolumeTile(bytes: 20 * 1024 * 1024 * 1024, label: "20 GB (大文件)")
                        }
                    }
                }
            }
            .padding(18)
            .background(Color.primary.opacity(0.025))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            
            VStack(alignment: .leading, spacing: 14) {
                Label("杂质清理与过滤规则", systemImage: "shield.checkerboard")
                    .font(.system(size: 13, weight: .bold, design: .serif))
                    .foregroundStyle(TTZipTheme.bambooGreen)
                
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(isOn: $editorSkipMacJunk) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash.circle")
                                .font(.system(size: 12))
                                .foregroundStyle(TTZipTheme.bambooGreen)
                            Text("自动过滤 Mac 系统杂质文件 (.DS_Store / __MACOSX 缓存)")
                                .font(.system(size: 11.5))
                        }
                    }
                    .toggleStyle(.checkbox)
                    
                    Toggle(isOn: $editorSkipGitDirectory) {
                        HStack(spacing: 6) {
                            Image(systemName: "folder.badge.gearshape")
                                .font(.system(size: 12))
                                .foregroundStyle(TTZipTheme.bambooGreen)
                            Text("自动过滤 .git 源码版本控制目录")
                                .font(.system(size: 11.5))
                        }
                    }
                    .toggleStyle(.checkbox)
                }
                .padding(.leading, 12)
            }
            .padding(18)
            .background(Color.primary.opacity(0.025))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
    }
    
    private func splitVolumeTile(bytes: Int64?, label: String) -> some View {
        let isSelected = editorSplitVolumeOption == bytes
        return Button(action: { editorSplitVolumeOption = bytes }) {
            Text(label)
                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? TTZipTheme.kintsugiGold : Color.primary)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(isSelected ? TTZipTheme.kintsugiGold.opacity(0.15) : Color.primary.opacity(0.03))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? TTZipTheme.kintsugiGold : Color.primary.opacity(0.06), lineWidth: isSelected ? 1.2 : 0.5)
                )
        }
        .buttonStyle(.plain)
    }
}
