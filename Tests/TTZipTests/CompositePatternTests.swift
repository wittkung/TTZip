import XCTest
@testable import TTZipCore

final class CompositePatternTests: XCTestCase {
    
    // MARK: - 1. ArchiveLeafFile 叶子节点测试
    
    func testArchiveLeafFileBasicProperties() {
        let file = ArchiveLeafFile(name: "test.txt", path: "documents/test.txt", sizeBytes: 1024)
        
        XCTAssertEqual(file.name, "test.txt")
        XCTAssertEqual(file.path, "documents/test.txt")
        XCTAssertFalse(file.isDirectory)
        XCTAssertEqual(file.sizeBytes, 1024)
        XCTAssertTrue(file.getChildren().isEmpty)
    }
    
    // MARK: - 2. ArchiveCompositeDirectory 容器节点测试与动态尺寸计算
    
    func testArchiveCompositeDirectoryDynamicSize() {
        let root = ArchiveCompositeDirectory(name: "Root", path: "Root")
        let subDir = ArchiveCompositeDirectory(name: "Photos", path: "Root/Photos")
        
        let file1 = ArchiveLeafFile(name: "doc.pdf", path: "Root/doc.pdf", sizeBytes: 500)
        let file2 = ArchiveLeafFile(name: "pic1.jpg", path: "Root/Photos/pic1.jpg", sizeBytes: 2000)
        let file3 = ArchiveLeafFile(name: "pic2.png", path: "Root/Photos/pic2.png", sizeBytes: 1500)
        
        subDir.add(component: file2)
        subDir.add(component: file3)
        
        root.add(component: file1)
        root.add(component: subDir)
        
        XCTAssertTrue(root.isDirectory)
        XCTAssertEqual(subDir.sizeBytes, 3500)
        XCTAssertEqual(root.sizeBytes, 4000) // 500 + 2000 + 1500
        
        // 动态移除节点
        subDir.remove(componentNamed: "pic1.jpg")
        XCTAssertEqual(subDir.sizeBytes, 1500)
        XCTAssertEqual(root.sizeBytes, 2000)
    }
    
    func testArchiveCompositeDirectoryChildOperations() {
        let dir = ArchiveCompositeDirectory(name: "Folder", path: "Folder")
        let fileA = ArchiveLeafFile(name: "b.txt", path: "Folder/b.txt", sizeBytes: 100)
        let fileB = ArchiveLeafFile(name: "a.txt", path: "Folder/a.txt", sizeBytes: 200)
        let subDir = ArchiveCompositeDirectory(name: "Sub", path: "Folder/Sub")
        
        dir.add(component: fileA)
        dir.add(component: fileB)
        dir.add(component: subDir)
        
        let children = dir.getChildren()
        XCTAssertEqual(children.count, 3)
        
        // 验证目录优先排在前面，其次名称按字母升序
        XCTAssertTrue(children[0].isDirectory)
        XCTAssertEqual(children[0].name, "Sub")
        XCTAssertEqual(children[1].name, "a.txt")
        XCTAssertEqual(children[2].name, "b.txt")
        
        XCTAssertNotNil(dir.findChild(named: "a.txt"))
        dir.removeAll()
        XCTAssertTrue(dir.getChildren().isEmpty)
    }
    
    // MARK: - 3. ArchiveComponentTreeBuilder 从 ArchiveEntry 算法树构建测试
    
    func testTreeBuilderFromArchiveEntries() {
        let entries = [
            ArchiveEntry(path: "Docs/README.md", uncompressedSize: 300, isDirectory: false),
            ArchiveEntry(path: "Docs/Guide.pdf", uncompressedSize: 1200, isDirectory: false),
            ArchiveEntry(path: "Images/Logo.png", uncompressedSize: 800, isDirectory: false),
            ArchiveEntry(path: "RootConfig.json", uncompressedSize: 150, isDirectory: false),
            ArchiveEntry(path: "EmptyFolder/", uncompressedSize: 0, isDirectory: true)
        ]
        
        let root = ArchiveComponentTreeBuilder.buildTree(from: entries)
        
        XCTAssertTrue(root.isDirectory)
        XCTAssertEqual(root.sizeBytes, 2450)
        XCTAssertEqual(root.totalFileCount(), 4)
        XCTAssertEqual(root.totalDirectoryCount(), 3) // Docs, Images, EmptyFolder
        
        let leaves = root.flattenLeaves()
        XCTAssertEqual(leaves.count, 4)
    }
    
    // MARK: - 4. 磁盘路径 Composite Tree 构建与度量测试
    
    func testTreeBuilderFromDiskPath() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let subDir = tempDir.appendingPathComponent("Sub")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        
        let file1 = tempDir.appendingPathComponent("file1.txt")
        let file2 = subDir.appendingPathComponent("file2.jpg")
        
        try "Hello World".write(to: file1, atomically: true, encoding: .utf8)
        try "Image Data".write(to: file2, atomically: true, encoding: .utf8)
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        let component = ArchiveComponentTreeBuilder.buildTree(fromDiskPath: tempDir.path)
        
        XCTAssertTrue(component.isDirectory)
        XCTAssertEqual(component.totalFileCount(), 2)
        XCTAssertEqual(component.totalDirectoryCount(), 1)
        XCTAssertGreaterThan(component.sizeBytes, 0)
    }
    
    // MARK: - 5. Visitor Pattern 访问者模式测试
    
    private final class CustomCountingVisitor: ArchiveComponentVisitorProtocol {
        typealias Result = (fileNames: [String], dirNames: [String])
        
        func visit(leaf: ArchiveLeafFile) -> Result {
            return (fileNames: [leaf.name], dirNames: [])
        }
        
        func visit(directory: ArchiveCompositeDirectory) -> Result {
            var files: [String] = []
            var dirs: [String] = []
            if !directory.name.isEmpty {
                dirs.append(directory.name)
            }
            for child in directory.getChildren() {
                let res = child.accept(visitor: self)
                files.append(contentsOf: res.fileNames)
                dirs.append(contentsOf: res.dirNames)
            }
            return (fileNames: files, dirNames: dirs)
        }
    }
    
    func testVisitorPatternTraversal() {
        let root = ArchiveCompositeDirectory(name: "Root", path: "Root")
        let file = ArchiveLeafFile(name: "a.txt", path: "Root/a.txt", sizeBytes: 10)
        let sub = ArchiveCompositeDirectory(name: "Sub", path: "Root/Sub")
        let file2 = ArchiveLeafFile(name: "b.txt", path: "Root/Sub/b.txt", sizeBytes: 20)
        
        sub.add(component: file2)
        root.add(component: file)
        root.add(component: sub)
        
        let visitor = CustomCountingVisitor()
        let result = root.accept(visitor: visitor)
        
        XCTAssertEqual(result.fileNames.sorted(), ["a.txt", "b.txt"])
        XCTAssertEqual(result.dirNames.sorted(), ["Root", "Sub"])
    }
    
    // MARK: - 6. ArchiveTreeNode 互操作与 Composite 重构集成测试
    
    func testArchiveTreeNodeCompositeInterop() {
        let entries = [
            ArchiveEntry(path: "Folder/File1.txt", uncompressedSize: 100, isDirectory: false),
            ArchiveEntry(path: "Folder/File2.txt", uncompressedSize: 200, isDirectory: false)
        ]
        
        let treeNodes = ArchiveTreeBuilder.buildTree(from: entries)
        XCTAssertEqual(treeNodes.count, 1)
        
        let folderNode = treeNodes[0]
        XCTAssertTrue(folderNode.isDirectory)
        XCTAssertEqual(folderNode.sizeBytes, 300)
        
        let component = folderNode.toComponent()
        XCTAssertTrue(component.isDirectory)
        XCTAssertEqual(component.sizeBytes, 300)
        XCTAssertEqual(component.getChildren().count, 2)
        
        let restoredNode = ArchiveTreeNode(component: component)
        XCTAssertEqual(restoredNode.name, folderNode.name)
        XCTAssertEqual(restoredNode.uncompressedSize, folderNode.uncompressedSize)
    }
    
    // MARK: - 7. FolderStatsCalculator Composite 集成测试
    
    func testFolderStatsCalculatorWithCompositeComponent() {
        let root = ArchiveCompositeDirectory(name: "Root", path: "Root")
        let video = ArchiveLeafFile(name: "movie.mp4", path: "Root/movie.mp4", sizeBytes: 1000)
        let audio = ArchiveLeafFile(name: "song.mp3", path: "Root/song.mp3", sizeBytes: 500)
        let code = ArchiveLeafFile(name: "main.swift", path: "Root/main.swift", sizeBytes: 200)
        
        root.add(component: video)
        root.add(component: audio)
        root.add(component: code)
        
        let stats = FolderStatsCalculator.calculateStats(for: root)
        
        XCTAssertEqual(stats.size, 1700)
        XCTAssertEqual(stats.files, 3)
        XCTAssertEqual(stats.subfolders, 0)
        XCTAssertEqual(stats.dist.count, 3)
    }
    
    // MARK: - 8. SecurityScanner Composite 集成测试
    
    func testSecurityScannerWithCompositeComponent() {
        let root = ArchiveCompositeDirectory(name: "Archive", path: "Archive")
        let safeFile = ArchiveLeafFile(name: "document.pdf", path: "Archive/document.pdf", sizeBytes: 500)
        let dangerousFile = ArchiveLeafFile(name: "hack.sh", path: "Archive/hack.sh", sizeBytes: 100)
        
        root.add(component: safeFile)
        root.add(component: dangerousFile)
        
        let result = SecurityScanner.shared.scanComponent(root)
        
        XCTAssertFalse(result.isSafe)
        XCTAssertEqual(result.suspiciousFileNames, ["Archive/hack.sh"])
    }
    
    // MARK: - 9. 磁盘 Composite Size 动态度量测试
    
    func testDiskCompositeSizeMeasurement() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let f1 = tempDir.appendingPathComponent("test1.txt")
        try "12345".write(to: f1, atomically: true, encoding: .utf8)
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        let component = ArchiveComponentTreeBuilder.buildTree(fromDiskPath: tempDir.path)
        XCTAssertTrue(component.isDirectory)
        XCTAssertEqual(component.sizeBytes, 5)
    }

    // MARK: - 10. renderTree 树形 ASCII 格式化与 Sequence 扩展测试

    func testRenderTreeFormattingAndSequenceExtensions() {
        let root = ArchiveCompositeDirectory(name: "Project", path: "Project")
        let src = ArchiveCompositeDirectory(name: "Sources", path: "Project/Sources")
        let file1 = ArchiveLeafFile(name: "main.swift", path: "Project/Sources/main.swift", sizeBytes: 150)
        let file2 = ArchiveLeafFile(name: "README.md", path: "Project/README.md", sizeBytes: 200)

        src.add(component: file1)
        root.add(component: src)
        root.add(component: file2)

        let treeStr = root.renderTree()
        XCTAssertTrue(treeStr.contains("Project (<DIR>)"))
        XCTAssertTrue(treeStr.contains("Sources (<DIR>)"))
        XCTAssertTrue(treeStr.contains("main.swift") && treeStr.contains("150"))
        XCTAssertTrue(treeStr.contains("README.md") && treeStr.contains("200"))

        let components: [ArchiveComponentProtocol] = [root]
        XCTAssertEqual(components.totalSizeBytes, 350)
        XCTAssertEqual(components.totalFileCount, 2)
        XCTAssertEqual(components.totalDirectoryCount, 1)
        XCTAssertEqual(components.flattenLeaves().count, 2)
    }

    // MARK: - 11. ArchiveReader.inspectTree 组合树解析与 ZipDirectoryScanner 测试

    func testArchiveReaderInspectTreeAndScannerIntegration() async throws {
        let entries = [
            ArchiveEntry(path: "App/main.swift", uncompressedSize: 500, isDirectory: false),
            ArchiveEntry(path: "App/Assets/icon.png", uncompressedSize: 1200, isDirectory: false)
        ]
        let tree = ArchiveComponentTreeBuilder.buildTree(from: entries)
        XCTAssertTrue(tree.isDirectory)
        XCTAssertEqual(tree.totalFileCount(), 2)

        let scannedItems = ZipDirectoryScanner.scanComponent(tree, baseRelPath: "App")
        XCTAssertGreaterThanOrEqual(scannedItems.count, 2)
    }

    // MARK: - 12. ArchiveTreeNode 目录节点 sizeBytes 递归聚合修复验证

    func testArchiveTreeNodeDirectorySizeBytesRecursiveAggregation() {
        // 目录节点 uncompressedSize == 0，但包含子节点，sizeBytes 应透明递归计算
        let child1 = ArchiveTreeNode(
            id: "dir/a.txt", name: "a.txt", path: "dir/a.txt",
            uncompressedSize: 100, isDirectory: false
        )
        let child2 = ArchiveTreeNode(
            id: "dir/b.txt", name: "b.txt", path: "dir/b.txt",
            uncompressedSize: 250, isDirectory: false
        )
        let dirNode = ArchiveTreeNode(
            id: "dir", name: "dir", path: "dir",
            uncompressedSize: 0, isDirectory: true,
            children: [child1, child2]
        )
        
        // 核心断言：目录 sizeBytes == 子节点之和
        XCTAssertEqual(dirNode.sizeBytes, 350)
        
        // 叶子节点 sizeBytes 仍直接返回 uncompressedSize
        XCTAssertEqual(child1.sizeBytes, 100)
    }

    func testArchiveTreeNodeNestedDirectorySizeTransitivity() {
        // 嵌套多层目录，sizeBytes 应逐层递归
        let leaf = ArchiveTreeNode(
            id: "root/sub/file.dat", name: "file.dat", path: "root/sub/file.dat",
            uncompressedSize: 500, isDirectory: false
        )
        let subDir = ArchiveTreeNode(
            id: "root/sub", name: "sub", path: "root/sub",
            uncompressedSize: 0, isDirectory: true,
            children: [leaf]
        )
        let rootDir = ArchiveTreeNode(
            id: "root", name: "root", path: "root",
            uncompressedSize: 0, isDirectory: true,
            children: [subDir]
        )
        
        XCTAssertEqual(subDir.sizeBytes, 500)
        XCTAssertEqual(rootDir.sizeBytes, 500)
    }
    
    // MARK: - 13. ArchiveCompositeDirectory O(1) findChild 查找验证

    func testCompositeDirectoryFindChildO1Lookup() {
        let dir = ArchiveCompositeDirectory(name: "Root", path: "Root")
        let subA = ArchiveCompositeDirectory(name: "Alpha", path: "Root/Alpha")
        let subB = ArchiveCompositeDirectory(name: "Beta", path: "Root/Beta")
        let file = ArchiveLeafFile(name: "readme.md", path: "Root/readme.md", sizeBytes: 42)
        
        dir.add(component: subA)
        dir.add(component: subB)
        dir.add(component: file)
        
        // O(1) 精确查找
        let foundAlpha = dir.findChild(named: "Alpha")
        XCTAssertNotNil(foundAlpha)
        XCTAssertEqual(foundAlpha?.name, "Alpha")
        XCTAssertTrue(foundAlpha?.isDirectory ?? false)
        
        let foundFile = dir.findChild(named: "readme.md")
        XCTAssertNotNil(foundFile)
        XCTAssertEqual(foundFile?.sizeBytes, 42)
        
        // 不存在的名称返回 nil
        XCTAssertNil(dir.findChild(named: "NonExistent"))
    }
    
    // MARK: - 14. ArchiveTreeNode 与 ArchiveTreeBuilder sizeBytes 端到端一致性

    func testArchiveTreeBuilderNodeSizeBytesEndToEnd() {
        let entries = [
            ArchiveEntry(path: "Project/src/main.swift", uncompressedSize: 200, isDirectory: false),
            ArchiveEntry(path: "Project/src/utils.swift", uncompressedSize: 150, isDirectory: false),
            ArchiveEntry(path: "Project/README.md", uncompressedSize: 50, isDirectory: false)
        ]
        
        let treeNodes = ArchiveTreeBuilder.buildTree(from: entries)
        XCTAssertEqual(treeNodes.count, 1)
        
        let projectNode = treeNodes[0]
        XCTAssertTrue(projectNode.isDirectory)
        // ArchiveTreeNode.sizeBytes 应递归计算 == 200 + 150 + 50
        XCTAssertEqual(projectNode.sizeBytes, 400)
        
        // 对比 toComponent() 路径的 sizeBytes，两者必须一致
        let component = projectNode.toComponent()
        XCTAssertEqual(component.sizeBytes, projectNode.sizeBytes)
    }
}
