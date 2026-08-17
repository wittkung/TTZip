import Foundation
import CTTZipBridge

/// 损坏归档修复与容灾恢复引擎
public final class ArchiveRepairEngine: @unchecked Sendable {
    public init() {}
    
    /// 扫描损坏的归档文件并重构提取可读的数据块至修复包 (结合 ArchiveRepairStrategyContext 策略模式)
    public func repairArchive(damagedArchivePath: String, repairedOutputPath: String) async throws -> Int {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: damagedArchivePath) else {
            throw ArchiveError.fileNotFound
        }
        
        ArchiveProgressBroadcaster.shared.broadcastProgress(ArchiveProgressInfo(
            state: .processing,
            bytesProcessed: 0,
            totalBytes: 100,
            currentFileName: (damagedArchivePath as NSString).lastPathComponent,
            throughputMBs: 0,
            estimatedTimeRemaining: nil,
            operationType: .repair
        ))
        
        let count = try await ArchiveRepairStrategyContext.shared.repairArchive(
            damagedArchivePath: damagedArchivePath,
            repairedOutputPath: repairedOutputPath
        )
        
        ArchiveProgressBroadcaster.shared.broadcastProgress(ArchiveProgressInfo(
            state: .completed,
            bytesProcessed: Int64(count),
            totalBytes: Int64(count),
            currentFileName: (repairedOutputPath as NSString).lastPathComponent,
            throughputMBs: 0,
            estimatedTimeRemaining: 0,
            operationType: .repair
        ))
        
        ArchiveEventCenter.shared.postArchiveCompleted(
            archivePath: repairedOutputPath,
            operationType: .repair,
            duration: 0.1,
            totalBytes: Int64(count)
        )
        
        return count
    }
}
