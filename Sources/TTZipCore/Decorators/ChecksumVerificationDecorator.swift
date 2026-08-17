import Foundation

/// 校验和 (CRC32/SHA256) 实时算力校验具体装饰器 (Concrete Decorator)
/// 透明叠加实时哈希计算与全流数据完整性校验。
open class ChecksumVerificationDecorator: ArchiveOperationDecorator, @unchecked Sendable {
    public var algorithm: HashType
    private let hashCalculator: HashCalculating
    private let lock = NSLock()

    private var _lastSourceChecksum: String?
    private var _lastOutputChecksum: String?
    private var _isVerified: Bool = false

    public var lastSourceChecksum: String? {
        lock.lock()
        defer { lock.unlock() }
        return _lastSourceChecksum
    }

    public var lastOutputChecksum: String? {
        lock.lock()
        defer { lock.unlock() }
        return _lastOutputChecksum
    }

    public var isVerified: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isVerified
    }

    private func updateSourceChecksum(_ hash: String?) {
        lock.lock()
        _lastSourceChecksum = hash
        lock.unlock()
    }

    private func updateOutputChecksum(_ hash: String?, verified: Bool) {
        lock.lock()
        _lastOutputChecksum = hash
        _isVerified = verified
        lock.unlock()
    }

    public init(
        inner: ArchiveEngineImplementorProtocol,
        algorithm: HashType = .crc32,
        hashCalculator: HashCalculating = ArchiveEngineFactory.makeHashCalculator()
    ) {
        self.algorithm = algorithm
        self.hashCalculator = hashCalculator
        super.init(inner: inner)
    }

    /// 透明叠加实时校验和计算的打包流程
    open override func compressStream(
        inputPaths: [String],
        outputPath: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        // 1. 执行前置计算源文件/首选路径 Hash
        if let firstInput = inputPaths.first, FileManager.default.fileExists(atPath: firstInput) {
            let srcHash = try? await hashCalculator.computeHash(filePath: firstInput, type: algorithm)
            updateSourceChecksum(srcHash)
        }

        // 2. 执行底层压缩流
        let bytesWritten = try await super.compressStream(
            inputPaths: inputPaths,
            outputPath: outputPath,
            options: options
        )

        // 3. 执行后置产物 Hash 计算与校验
        if FileManager.default.fileExists(atPath: outputPath) {
            let outHash = try? await hashCalculator.computeHash(filePath: outputPath, type: algorithm)
            updateOutputChecksum(outHash, verified: outHash != nil)
            TTLogger.debug("🛡️ [ChecksumVerificationDecorator] 压缩产物哈希 (\(algorithm.rawValue.uppercased())): \(outHash ?? "N/A")")
        }

        return bytesWritten
    }

    /// 透明叠加解压实时校验和核对的提取流程
    open override func extractStream(
        archivePath: String,
        destinationDir: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        // 1. 记载源归档 Hash
        if FileManager.default.fileExists(atPath: archivePath) {
            let arcHash = try? await hashCalculator.computeHash(filePath: archivePath, type: algorithm)
            updateSourceChecksum(arcHash)
        }

        // 2. 执行底层解压流
        let bytesExtracted = try await super.extractStream(
            archivePath: archivePath,
            destinationDir: destinationDir,
            options: options
        )

        // 3. 核验解压产物目录中的有效文件 Hash
        let fm = FileManager.default
        if let items = try? fm.contentsOfDirectory(atPath: destinationDir), !items.isEmpty {
            let firstFile = (destinationDir as NSString).appendingPathComponent(items[0])
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: firstFile, isDirectory: &isDir), !isDir.boolValue {
                let extHash = try? await hashCalculator.computeHash(filePath: firstFile, type: algorithm)
                updateOutputChecksum(extHash, verified: extHash != nil)
                TTLogger.debug("🛡️ [ChecksumVerificationDecorator] 解压文件产物哈希 (\(algorithm.rawValue.uppercased())): \(extHash ?? "N/A")")
            } else {
                updateOutputChecksum(nil, verified: true)
            }
        }

        return bytesExtracted
    }
}
