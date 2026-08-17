import Foundation

/// 7-Zip 固实归档 (Solid Archiving) 与超大固实数据块引擎
public final class SolidArchiveEngine: @unchecked Sendable {
    public init() {}
    
    /// 将多个同类文件以原生固实数据块 (Solid Block) 打包，最大化利用重复模式剔除冗余，提升代码库与文本压缩比
    public func createSolidArchive(
        outputPath: String,
        inputPaths: [String],
        format: ArchiveCompressionFormat = .sevenZip,
        dictionarySizeMB: Int = 1024
    ) async throws {
        guard !inputPaths.isEmpty else {
            throw ArchiveError.readFailed(code: -10)
        }
        
        let writer = ArchiveEngineFactory.makeWriter(for: format)
        _ = try await ArchivePipelineBuilder()
            .withWriter(writer)
            .withOutputPath(outputPath)
            .withFormat(format)
            .withLevel(.ultra)
            .withInputPaths(inputPaths)
            .configureOptions { builder in
                builder = builder
                    .withAlgorithm("LZMA2")
                    .withDictionarySizeMB(dictionarySizeMB)
                    .withCpuThreads(AppleSiliconTuner.shared.optimalBurstThreads)
                    .withSolidArchive(true)
                    .withEncryptFileNames(false)
                    .withZstdLevel(3)
                    .withZstdEnableLDM(true)
            }
            .executeCreate()
    }
}
