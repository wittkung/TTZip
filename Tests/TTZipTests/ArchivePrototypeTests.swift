import XCTest
@testable import TTZipCore
@testable import TTZipApp

final class ArchivePrototypeTests: XCTestCase {
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        PresetManager.shared.resetToDefaults()
    }
    
    // MARK: - 1. CompressionPreset Prototype Pattern Tests
    func testCompressionPresetDefaultClone() {
        let original = CompressionPreset(
            name: "7Z 极速发布包",
            format: .sevenZip,
            level: .fastest,
            splitVolumeSizeBytes: 100 * 1024 * 1024,
            defaultPassword: "SecurePassword123",
            skipMacJunk: true,
            skipGitDirectory: true
        )
        
        let clone = original.clone()
        
        // 必须分配全新的 UUID
        XCTAssertNotEqual(original.id, clone.id)
        // 所有业务属性必须精确全量继承
        XCTAssertEqual(clone.name, original.name)
        XCTAssertEqual(clone.format, original.format)
        XCTAssertEqual(clone.level, original.level)
        XCTAssertEqual(clone.splitVolumeSizeBytes, original.splitVolumeSizeBytes)
        XCTAssertEqual(clone.defaultPassword, original.defaultPassword)
        XCTAssertEqual(clone.skipMacJunk, original.skipMacJunk)
        XCTAssertEqual(clone.skipGitDirectory, original.skipGitDirectory)
    }
    
    func testCompressionPresetSpecializedClone() {
        let original = CompressionPreset(
            name: "ZIP 标准模板",
            format: .zip,
            level: .normal,
            splitVolumeSizeBytes: nil,
            defaultPassword: nil,
            skipMacJunk: true,
            skipGitDirectory: false
        )
        
        let customId = UUID()
        let customName = "ZIP 衍生私有模板"
        let clone = original.clone(newId: customId, newName: customName)
        
        XCTAssertEqual(clone.id, customId)
        XCTAssertEqual(clone.name, customName)
        XCTAssertEqual(clone.format, .zip)
        XCTAssertEqual(clone.level, .normal)
        XCTAssertNil(clone.splitVolumeSizeBytes)
        XCTAssertEqual(clone.skipMacJunk, true)
        XCTAssertEqual(clone.skipGitDirectory, false)
        
        // 验证克隆后的独立可变性，原对象不受任何副作用影响
        var mutableClone = clone
        mutableClone.name = "已修改名字"
        mutableClone.level = .ultra
        
        XCTAssertEqual(original.name, "ZIP 标准模板")
        XCTAssertEqual(original.level, .normal)
    }
    
    // MARK: - 2. ArchiveFilterOptions Prototype Pattern Tests
    func testArchiveFilterOptionsClone() {
        let original = ArchiveFilterOptions(
            skipMacJunk: true,
            skipGitDirectory: true,
            customIgnorePatterns: ["*.tmp", "*.log", ".DS_Store"]
        )
        
        let snapshot = original.clone()
        
        XCTAssertEqual(snapshot.skipMacJunk, original.skipMacJunk)
        XCTAssertEqual(snapshot.skipGitDirectory, original.skipGitDirectory)
        XCTAssertEqual(snapshot.customIgnorePatterns, original.customIgnorePatterns)
        XCTAssertEqual(snapshot, original)
    }
    
    func testArchiveFilterOptionsMutateClone() {
        let original = ArchiveFilterOptions.defaultClean
        
        let mutated = original.clone { options in
            options.skipGitDirectory = true
            options.customIgnorePatterns.append("node_modules")
        }
        
        // 原对象必须保持干净清洁的原生值
        XCTAssertEqual(original.skipGitDirectory, false)
        XCTAssertTrue(original.customIgnorePatterns.isEmpty)
        
        // 变异副本必须更新对应字段
        XCTAssertEqual(mutated.skipGitDirectory, true)
        XCTAssertEqual(mutated.skipMacJunk, true)
        XCTAssertEqual(mutated.customIgnorePatterns, ["node_modules"])
    }
    
    // MARK: - 3. ArchiveAdvancedOptions Prototype Pattern Tests
    func testArchiveAdvancedOptionsClone() {
        var original = ArchiveAdvancedOptions.defaultOptions
        original.cpuThreads = 8
        original.sevenZipOptions.algorithm = "PPMd"
        original.sevenZipOptions.dictionarySizeMB = 128
        original.zipOptions.zipEncryptionMethod = "ZipCrypto"
        original.zstdOptions.zstdLevel = 19
        
        let clone = original.clone()
        
        XCTAssertEqual(clone.cpuThreads, 8)
        XCTAssertEqual(clone.sevenZipOptions.algorithm, "PPMd")
        XCTAssertEqual(clone.sevenZipOptions.dictionarySizeMB, 128)
        XCTAssertEqual(clone.zipOptions.zipEncryptionMethod, "ZipCrypto")
        XCTAssertEqual(clone.zstdOptions.zstdLevel, 19)
        
        // 修改克隆对象的内部属性
        var modifiedClone = clone
        modifiedClone.cpuThreads = 2
        modifiedClone.sevenZipOptions.algorithm = "LZMA2"
        
        XCTAssertEqual(original.cpuThreads, 8)
        XCTAssertEqual(original.sevenZipOptions.algorithm, "PPMd")
    }
    
    // MARK: - 4. ArchiveTreeNode Deep Prototype Tree Clone Tests
    func testArchiveTreeNodeLeafClone() {
        let entry = ArchiveEntry(path: "docs/readme.txt", uncompressedSize: 2048, isDirectory: false)
        let leafNode = ArchiveTreeNode(
            id: "docs/readme.txt",
            name: "readme.txt",
            path: "docs/readme.txt",
            uncompressedSize: 2048,
            isDirectory: false,
            detectedEncoding: "UTF-8",
            children: nil,
            entry: entry
        )
        
        let clonedLeaf = leafNode.cloneTree()
        
        XCTAssertEqual(clonedLeaf, leafNode)
        XCTAssertEqual(clonedLeaf.name, "readme.txt")
        XCTAssertEqual(clonedLeaf.uncompressedSize, 2048)
        XCTAssertEqual(clonedLeaf.entry, entry)
    }
    
    func testArchiveTreeNodeTreeDeepClone() {
        let file1 = ArchiveTreeNode(id: "root/f1.txt", name: "f1.txt", path: "root/f1.txt", uncompressedSize: 100, isDirectory: false)
        let file2 = ArchiveTreeNode(id: "root/f2.txt", name: "f2.txt", path: "root/f2.txt", uncompressedSize: 200, isDirectory: false)
        let subDir = ArchiveTreeNode(id: "root/sub", name: "sub", path: "root/sub", uncompressedSize: 300, isDirectory: true, children: [file2])
        
        let rootTree = ArchiveTreeNode(
            id: "root",
            name: "root",
            path: "root",
            uncompressedSize: 400,
            isDirectory: true,
            children: [file1, subDir]
        )
        
        let clonedTree = rootTree.cloneTree()
        
        // 树结构全面相等
        XCTAssertEqual(clonedTree, rootTree)
        XCTAssertEqual(clonedTree.children?.count, 2)
        XCTAssertEqual(clonedTree.children?[1].children?.count, 1)
        XCTAssertEqual(clonedTree.children?[1].children?[0].name, "f2.txt")
        
        // 验证深拷贝隔离性：在克隆树上修改子节点，不破坏原始树
        var modifiedTree = clonedTree
        modifiedTree.children?[0] = ArchiveTreeNode(id: "root/new.txt", name: "new.txt", path: "root/new.txt", uncompressedSize: 999, isDirectory: false)
        
        XCTAssertEqual(rootTree.children?[0].name, "f1.txt")
        XCTAssertEqual(modifiedTree.children?[0].name, "new.txt")
    }
    
    // MARK: - 5. PresetManager Prototype Integration Tests
    func testPresetManagerDuplicatePreset() {
        let manager = PresetManager.shared
        manager.resetToDefaults()
        let initialCount = manager.presets.count
        guard let first = manager.presets.first else {
            XCTFail("Default presets must exist")
            return
        }
        
        let duplicated = manager.duplicatePreset(id: first.id, newName: "7Z 20GB 专属衍生")
        XCTAssertNotNil(duplicated)
        XCTAssertEqual(duplicated?.name, "7Z 20GB 专属衍生")
        XCTAssertEqual(duplicated?.format, first.format)
        XCTAssertEqual(duplicated?.level, first.level)
        XCTAssertEqual(duplicated?.splitVolumeSizeBytes, first.splitVolumeSizeBytes)
        XCTAssertNotEqual(duplicated?.id, first.id)
        
        XCTAssertEqual(manager.presets.count, initialCount + 1)
    }
    
    func testPresetManagerCreatePresetFromPrototype() {
        let manager = PresetManager.shared
        manager.resetToDefaults()
        let initialCount = manager.presets.count
        
        let customPrototype = CompressionPreset(
            name: "极客专属 ZSTD 模板",
            format: .tarZst,
            level: .ultra,
            splitVolumeSizeBytes: 1024 * 1024 * 1024,
            defaultPassword: "Pass",
            skipMacJunk: false,
            skipGitDirectory: true
        )
        
        let created = manager.createPresetFromPrototype(customPrototype, newName: "生产环境 ZSTD 预设")
        
        XCTAssertEqual(created.name, "生产环境 ZSTD 预设")
        XCTAssertEqual(created.format, .tarZst)
        XCTAssertEqual(created.level, .ultra)
        XCTAssertEqual(created.skipGitDirectory, true)
        XCTAssertEqual(manager.presets.count, initialCount + 1)
    }

    @MainActor
    func testPresetWorkspaceViewModelEmptyPresetsGuard() throws {
        let vm = PresetWorkspaceViewModel()
        vm.loadPresets()
        XCTAssertFalse(vm.presets.isEmpty)
        XCTAssertNotNil(vm.selectedPresetID)
        XCTAssertNotNil(vm.activeEditingPrototype)
    }
}

