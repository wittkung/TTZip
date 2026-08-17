import Foundation

/// 零拷贝静态 Silesia 语料库测试加载器 (基于 SPM Bundle.module 与直接路径回退)
public enum SilesiaFixtureLoader {
    
    /// 获取 Fixtures/Silesia 目录的根 URL
    public static func corpusDirectoryURL() throws -> URL {
        #if SWIFT_PACKAGE
        if let bundleURL = Bundle.module.url(forResource: "Silesia", withExtension: nil, subdirectory: "Fixtures") {
            return bundleURL
        }
        if let bundleURL = Bundle.module.url(forResource: "silesia_manifest", withExtension: "json", subdirectory: "Fixtures/Silesia") {
            return bundleURL.deletingLastPathComponent()
        }
        #endif
        
        if let envPath = ProcessInfo.processInfo.environment["TTZIP_SILESIA_PATH"], !envPath.isEmpty {
            let envURL = URL(fileURLWithPath: envPath)
            if FileManager.default.fileExists(atPath: envURL.path) {
                return envURL
            }
        }
        
        let sourceFile = URL(fileURLWithPath: #filePath)
        let fallbackURL = sourceFile.deletingLastPathComponent().appendingPathComponent("Fixtures/Silesia")
        if FileManager.default.fileExists(atPath: fallbackURL.path) {
            return fallbackURL
        }
        
        throw NSError(
            domain: "SilesiaFixtureLoader",
            code: 404,
            userInfo: [NSLocalizedDescriptionKey: "Silesia corpus directory not found in Bundle.module, TTZIP_SILESIA_PATH, or Tests/TTZipTests/Fixtures/Silesia/"]
        )
    }
    
    /// 获取指定 Silesia 语料文件的绝对 URL
    public static func fileURL(named filename: String) throws -> URL {
        let dir = try corpusDirectoryURL()
        let file = dir.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw NSError(
                domain: "SilesiaFixtureLoader",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Silesia corpus item '\(filename)' missing at '\(file.path)'"]
            )
        }
        return file
    }
    
    /// 获取指定 Silesia 语料文件的绝对物理路径 (供 C 引擎 open/mmap 直读)
    public static func filePath(named filename: String) throws -> String {
        return try fileURL(named: filename).path
    }
    
    /// 以零拷贝内核分页映射模式读取指定语料文件 (零堆分配)
    public static func mappedData(named filename: String) throws -> Data {
        let url = try fileURL(named: filename)
        return try Data(contentsOf: url, options: .alwaysMapped)
    }
    
    /// 获取 silesia_manifest.json 的 URL
    public static func manifestURL() throws -> URL {
        return try fileURL(named: "silesia_manifest.json")
    }
    
    /// 获取全部 12 个标准 Silesia 文件名列表
    public static let standardFileNames: [String] = [
        "dickens",
        "mozilla",
        "mr",
        "nci",
        "ooffice",
        "osdb",
        "reymont",
        "samba",
        "sao",
        "webster",
        "xml",
        "x-ray"
    ]
}
