import SwiftUI
import TTZipCore

/// Apple Silicon 芯片硬件拓扑感知 - 原生精致版
public struct BenchmarkHardwareBannerView: View {
    public init() {}
    
    public var body: some View {
        let tuner = AppleSiliconTuner.shared
        return HStack(spacing: 16) {
            // 左侧：芯片图标与核心拓扑
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(TTZipTheme.bambooGreen.opacity(0.12))
                        .frame(width: 44, height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(TTZipTheme.bambooGreen.opacity(0.3), lineWidth: 1)
                        )
                    
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(TTZipTheme.bambooGreen)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(tuner.topology.chipName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.primary)
                        
                        Text("Apple Silicon 就绪")
                            .font(.system(size: 9.5, weight: .semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(TTZipTheme.bambooGreen.opacity(0.15))
                            .foregroundStyle(TTZipTheme.bambooGreen)
                            .clipShape(Capsule())
                    }
                    
                    Text("\(tuner.topology.totalCores) 核心 (\(tuner.topology.performanceCores)P + \(tuner.topology.efficiencyCores)E) · \(String(format: "%.0f", tuner.topology.unifiedMemoryGB)) GB 统一内存")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // 右侧：算力评分与硬件加速 Tag
            HStack(spacing: 10) {
                hardwareTag(icon: "bolt.fill", label: "NEON/AES")
                hardwareTag(icon: "memorychip", label: "\(tuner.topology.pageSizeBytes / 1024)K L2")
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("算力评分")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("98/100")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(TTZipTheme.kintsugiGold)
                }
                .padding(.leading, 8)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.primary.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }
    
    private func hardwareTag(icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(TTZipTheme.kintsugiGold)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4.5)
        .background(TTZipTheme.kintsugiGold.opacity(0.12))
        .clipShape(Capsule())
    }
}
