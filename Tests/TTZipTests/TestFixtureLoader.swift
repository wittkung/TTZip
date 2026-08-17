import Foundation

/// 零拷贝静态归档测试语料加载器 (基于 SPM Bundle.module 资源包)
public enum TestFixtureLoader {
    
    /// 获取 Fixtures/Encrypted 目录下的静态测试归档 URL
    public static func encryptedFixtureURL(named filename: String) throws -> URL {
        let name: String
        let ext: String
        
        if let dotIndex = filename.lastIndex(of: ".") {
            name = String(filename[..<dotIndex])
            ext = String(filename[filename.index(after: dotIndex)...])
        } else {
            name = filename
            ext = ""
        }
        
        // 1. 尝试从 Bundle.module 资源包中加载
        #if SWIFT_PACKAGE
        if let resourceURL = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fixtures/Encrypted") {
            return resourceURL
        }
        if let resourceURL = Bundle.module.url(forResource: filename, withExtension: nil, subdirectory: "Fixtures/Encrypted") {
            return resourceURL
        }
        #endif
        
        // 2. 尝试从当前测试源码目录回退查找 (兼容直接本地执行)
        let currentFile = URL(fileURLWithPath: #filePath)
        let testDir = currentFile.deletingLastPathComponent()
        let fallbackPath = testDir.appendingPathComponent("Fixtures/Encrypted/\(filename)")
        if FileManager.default.fileExists(atPath: fallbackPath.path) {
            return fallbackPath
        }
        
        throw NSError(
            domain: "TestFixtureLoader",
            code: 404,
            userInfo: [NSLocalizedDescriptionKey: "Test fixture '\(filename)' not found in Bundle.module or Fixtures/Encrypted/"]
        )
    }
    
    /// 获取静态测试归档的绝对物理路径 (供 C 引擎 open/mmap 直读)
    public static func encryptedFixturePath(named filename: String) throws -> String {
        return try encryptedFixtureURL(named: filename).path
    }
    
    /// 获取 HyperCompress 确定性微文件生成器实例
    public static func hyperCompressGenerator(profile: MicroCorpusProfile = .standardCiGate) -> HyperCompressCorpusGenerator {
        return HyperCompressCorpusGenerator(profile: profile)
    }
}
