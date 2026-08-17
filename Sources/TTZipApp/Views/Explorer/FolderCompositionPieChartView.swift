import SwiftUI
import TTZipCore

public struct PieSegment: Identifiable {
    public let id = UUID()
    public let category: String
    public let count: Int
    public let percentage: Double
    public let startAngle: Angle
    public let endAngle: Angle
    public let color: Color
}

public struct DonutShape: Shape {
    public var startAngle: Angle
    public var endAngle: Angle
    public var innerRadiusRatio: CGFloat = 0.6
    
    public init(startAngle: Angle, endAngle: Angle, innerRadiusRatio: CGFloat = 0.6) {
        self.startAngle = startAngle
        self.endAngle = endAngle
        self.innerRadiusRatio = innerRadiusRatio
    }
    
    public func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * innerRadiusRatio
        
        var path = Path()
        path.addArc(center: center, radius: outerRadius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.addArc(center: center, radius: innerRadius, startAngle: endAngle, endAngle: startAngle, clockwise: true)
        path.closeSubpath()
        return path
    }
}

public struct FolderCompositionPieChartView: View {
    public let distribution: [(category: String, count: Int)]
    
    public init(distribution: [(category: String, count: Int)]) {
        self.distribution = distribution
    }
    
    private var totalCount: Int {
        distribution.reduce(0) { $0 + $1.count }
    }
    
    private var segments: [PieSegment] {
        guard totalCount > 0 else { return [] }
        var currentAngle = Angle(degrees: -90)
        var result: [PieSegment] = []
        
        for item in distribution {
            let pct = Double(item.count) / Double(totalCount)
            let degrees = pct * 360.0
            let endAngle = currentAngle + Angle(degrees: degrees)
            
            let color: Color = {
                switch item.category {
                case "视频": return .red
                case "音频": return .purple
                case "图片": return .blue
                case "文档/代码/字幕": return TTZipTheme.bambooGreen
                case "归档包": return .orange
                default: return .gray
                }
            }()
            
            result.append(PieSegment(
                category: item.category,
                count: item.count,
                percentage: pct,
                startAngle: currentAngle,
                endAngle: endAngle,
                color: color
            ))
            currentAngle = endAngle
        }
        return result
    }
    
    public var body: some View {
        HStack(spacing: 14) {
            ZStack {
                ForEach(segments) { seg in
                    DonutShape(startAngle: seg.startAngle, endAngle: seg.endAngle)
                        .fill(seg.color)
                }
                
                VStack(spacing: 0) {
                    Text("\(totalCount)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("文件")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 76, height: 76)
            
            VStack(alignment: .leading, spacing: 3) {
                ForEach(segments) { seg in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(seg.color)
                            .frame(width: 6, height: 6)
                        
                        Text(seg.category)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        Text("\(seg.count)项 (\(Int(round(seg.percentage * 100)))%)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
