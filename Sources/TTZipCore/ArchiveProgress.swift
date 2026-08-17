import Foundation

/// 归档操作的实时进度与状态元数据
public struct ArchiveProgress: Sendable {
    public enum State: Sendable, Equatable {
        case idle
        case processing
        case completed
        case cancelled
        case failed(error: String)
    }
    
    public let state: State
    public let bytesProcessed: Int64
    public let totalBytes: Int64
    public let currentFileName: String
    public let throughputMBs: Double
    
    public var fractionCompleted: Double {
        guard totalBytes > 0 else { return 0.0 }
        return min(1.0, max(0.0, Double(bytesProcessed) / Double(totalBytes)))
    }
    
    public init(
        state: State = .idle,
        bytesProcessed: Int64 = 0,
        totalBytes: Int64 = 0,
        currentFileName: String = "",
        throughputMBs: Double = 0.0
    ) {
        self.state = state
        self.bytesProcessed = max(0, bytesProcessed)
        self.totalBytes = max(0, totalBytes)
        self.currentFileName = currentFileName
        self.throughputMBs = (throughputMBs.isNaN || throughputMBs.isInfinite || throughputMBs < 0) ? 0.0 : throughputMBs
    }
    
    public static let zero = ArchiveProgress()
}
