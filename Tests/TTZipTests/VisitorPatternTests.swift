import XCTest
import SwiftUI
@testable import TTZipCore
@testable import TTZipApp

final class VisitorPatternTests: XCTestCase {
    
    // MARK: - Helper Builders
    
    private func createSampleArchiveTree() -> ArchiveCompositeDirectory {
        let root = ArchiveCompositeDirectory(name: "Root", path: "Root")
        
        let docs = ArchiveCompositeDirectory(name: "Documents", path: "Root/Documents")
        let doc1 = ArchiveLeafFile(name: "readme.txt", path: "Root/Documents/readme.txt", sizeBytes: 1024)
        let doc2 = ArchiveLeafFile(name: "script.py", path: "Root/Documents/script.py", sizeBytes: 2048)
        docs.add(component: doc1)
        docs.add(component: doc2)
        
        let media = ArchiveCompositeDirectory(name: "Media", path: "Root/Media")
        let photos = ArchiveCompositeDirectory(name: "Photos", path: "Root/Media/Photos")
        let img1 = ArchiveLeafFile(name: "photo1.png", path: "Root/Media/Photos/photo1.png", sizeBytes: 4096)
        let img2 = ArchiveLeafFile(name: "photo2.jpg", path: "Root/Media/Photos/photo2.jpg", sizeBytes: 8192)
        photos.add(component: img1)
        photos.add(component: img2)
        media.add(component: photos)
        
        let video = ArchiveLeafFile(name: "movie.mp4", path: "Root/Media/movie.mp4", sizeBytes: 1_048_576)
        media.add(component: video)
        
        root.add(component: docs)
        root.add(component: media)
        
        return root
    }
    
    // MARK: - 1. SecurityScannerVisitor Tests
    
    func testSecurityScannerVisitorPathTraversalZipSlipDetection() {
        let root = ArchiveCompositeDirectory(name: "MaliciousRoot", path: "MaliciousRoot")
        let slipLeaf = ArchiveLeafFile(name: "passwd", path: "../../../etc/passwd", sizeBytes: 512)
        root.add(component: slipLeaf)
        
        let visitor = SecurityScannerVisitor()
        let threats = root.accept(visitor: visitor)
        
        XCTAssertEqual(threats.count, 1)
        XCTAssertEqual(threats.first?.type, .zipSlip)
        XCTAssertEqual(threats.first?.level, .critical)
        XCTAssertTrue(threats.first?.detail.contains("Zip Slip") == true)
    }
    
    func testSecurityScannerVisitorExecutableExtensionDetection() {
        let root = ArchiveCompositeDirectory(name: "Root", path: "Root")
        let exeLeaf = ArchiveLeafFile(name: "trojan.exe", path: "Root/trojan.exe", sizeBytes: 1024)
        let batLeaf = ArchiveLeafFile(name: "script.bat", path: "Root/script.bat", sizeBytes: 2048)
        let safeLeaf = ArchiveLeafFile(name: "document.pdf", path: "Root/document.pdf", sizeBytes: 4096)
        root.add(component: exeLeaf)
        root.add(component: batLeaf)
        root.add(component: safeLeaf)
        
        let visitor = SecurityScannerVisitor()
        let threats = root.accept(visitor: visitor)
        
        XCTAssertEqual(threats.count, 2)
        let threatTypes = Set(threats.map { $0.type })
        XCTAssertTrue(threatTypes.contains(.executableExtension))
        XCTAssertTrue(threats.allSatisfy { $0.level == .high })
    }
    
    func testSecurityScannerVisitorZipBombMultiplierDetection() {
        let root = ArchiveCompositeDirectory(name: "BombRoot", path: "BombRoot")
        let bombLeaf = ArchiveLeafFile(
            name: "huge_bomb.txt",
            path: "BombRoot/huge_bomb.txt",
            sizeBytes: 500_000_000,
            compressedSizeBytes: 100_000
        )
        root.add(component: bombLeaf)
        
        let visitor = SecurityScannerVisitor(maxCompressionRatio: 100.0)
        let threats = root.accept(visitor: visitor)
        
        XCTAssertFalse(threats.isEmpty)
        XCTAssertEqual(threats.first?.type, .zipBomb)
        XCTAssertEqual(threats.first?.level, .critical)
        XCTAssertTrue(threats.first?.detail.contains("Zip 炸弹") == true)
    }
    
    func testSecurityScannerVisitorCleanTreeNoThreats() {
        let tree = createSampleArchiveTree()
        let visitor = SecurityScannerVisitor()
        let threats = tree.accept(visitor: visitor)
        XCTAssertTrue(threats.isEmpty)
    }
    
    // MARK: - 2. FolderStatsVisitor Tests
    
    func testFolderStatsVisitorDeepTreeFileAndFolderCounts() {
        let tree = createSampleArchiveTree()
        let visitor = FolderStatsVisitor()
        let stats = tree.accept(visitor: visitor)
        
        // 5 files: readme.txt, script.py, photo1.png, photo2.jpg, movie.mp4
        // 3 subfolders: Documents, Media, Photos
        XCTAssertEqual(stats.totalFiles, 5)
        XCTAssertEqual(stats.totalDirectories, 3)
    }
    
    func testFolderStatsVisitorSizeAndMaxDepthComputation() {
        let tree = createSampleArchiveTree()
        let visitor = FolderStatsVisitor()
        let stats = tree.accept(visitor: visitor)
        
        let expectedSize: Int64 = 1024 + 2048 + 4096 + 8192 + 1_048_576
        XCTAssertEqual(stats.totalSizeBytes, expectedSize)
        
        // Root -> Media -> Photos -> photo1.png (depth = 4)
        XCTAssertEqual(stats.maxDepth, 4)
    }
    
    func testFolderStatsVisitorCategoryDistribution() {
        let tree = createSampleArchiveTree()
        let visitor = FolderStatsVisitor()
        let stats = tree.accept(visitor: visitor)
        
        XCTAssertFalse(stats.categoryDistribution.isEmpty)
        let videoCount = stats.categoryDistribution.first { $0.category == "视频" }?.count ?? 0
        let docCount = stats.categoryDistribution.first { $0.category == "文档/代码/字幕" }?.count ?? 0
        let photoCount = stats.categoryDistribution.first { $0.category == "图片" }?.count ?? 0
        
        XCTAssertEqual(videoCount, 1)
        XCTAssertEqual(docCount, 2)
        XCTAssertEqual(photoCount, 2)
    }
    
    // MARK: - 3. ChecksumCalculatorVisitor Tests
    
    func testChecksumCalculatorVisitorLeafFileChecksum() {
        let leaf = ArchiveLeafFile(name: "data.txt", path: "data.txt", sizeBytes: 100)
        let visitor = ChecksumCalculatorVisitor()
        let res = leaf.accept(visitor: visitor)
        
        XCTAssertNotEqual(res.crc32, 0)
        XCTAssertFalse(res.crc32String.isEmpty)
        XCTAssertFalse(res.sha256String.isEmpty)
        XCTAssertEqual(res.processedFiles, 1)
        XCTAssertEqual(res.totalSizeBytes, 100)
    }
    
    func testChecksumCalculatorVisitorCompositeTreeAggregation() {
        let tree = createSampleArchiveTree()
        let visitor = ChecksumCalculatorVisitor()
        let res = tree.accept(visitor: visitor)
        
        XCTAssertEqual(res.processedFiles, 5)
        XCTAssertEqual(res.totalSizeBytes, 1024 + 2048 + 4096 + 8192 + 1_048_576)
        XCTAssertFalse(res.crc32String.isEmpty)
        XCTAssertEqual(res.sha256String.count, 64) // SHA-256 hex string length is 64
    }
    
    func testChecksumCalculatorVisitorDeterministicSignatures() {
        let tree1 = createSampleArchiveTree()
        let tree2 = createSampleArchiveTree()
        
        let visitor1 = ChecksumCalculatorVisitor()
        let visitor2 = ChecksumCalculatorVisitor()
        
        let res1 = tree1.accept(visitor: visitor1)
        let res2 = tree2.accept(visitor: visitor2)
        
        XCTAssertEqual(res1.crc32, res2.crc32)
        XCTAssertEqual(res1.crc32String, res2.crc32String)
        XCTAssertEqual(res1.sha256String, res2.sha256String)
    }
    
    // MARK: - 4. TreeRendererVisitor Tests
    
    func testTreeRendererVisitorASCIITreeFormatting() {
        let root = ArchiveCompositeDirectory(name: "Project", path: "Project")
        let src = ArchiveCompositeDirectory(name: "src", path: "Project/src")
        let file1 = ArchiveLeafFile(name: "main.swift", path: "Project/src/main.swift", sizeBytes: 512)
        src.add(component: file1)
        
        let readme = ArchiveLeafFile(name: "README.md", path: "Project/README.md", sizeBytes: 256)
        root.add(component: src)
        root.add(component: readme)
        
        let visitor = TreeRendererVisitor()
        let treeOutput = root.accept(visitor: visitor)
        
        XCTAssertTrue(treeOutput.contains("Project/"))
        XCTAssertTrue(treeOutput.contains("├── src/"))
        XCTAssertTrue(treeOutput.contains("│   └── main.swift"))
        XCTAssertTrue(treeOutput.contains("└── README.md"))
    }
    
    func testTreeRendererVisitorWithSizeFormatting() {
        let root = ArchiveCompositeDirectory(name: "Folder", path: "Folder")
        let file = ArchiveLeafFile(name: "test.dat", path: "Folder/test.dat", sizeBytes: 1024 * 1024)
        root.add(component: file)
        
        let visitor = TreeRendererVisitor(includeSize: true)
        let output = root.accept(visitor: visitor)
        
        XCTAssertTrue(output.contains("Folder/"))
        XCTAssertTrue(output.contains("test.dat"))
    }
    
    func testTreeRendererVisitorEmptyDirectory() {
        let emptyDir = ArchiveCompositeDirectory(name: "Empty", path: "Empty")
        let visitor = TreeRendererVisitor()
        let output = emptyDir.accept(visitor: visitor)
        
        XCTAssertEqual(output, "Empty/")
    }
    
    // MARK: - 5. Concurrency & Integration Tests
    
    @MainActor
    func testConcurrentVisitorTraversal100Threads() {
        let tree = createSampleArchiveTree()
        let expectation = self.expectation(description: "100 Concurrent Visitor Executions")
        expectation.expectedFulfillmentCount = 100
        
        DispatchQueue.concurrentPerform(iterations: 100) { iteration in
            let secVisitor = SecurityScannerVisitor()
            let statsVisitor = FolderStatsVisitor()
            let checksumVisitor = ChecksumCalculatorVisitor()
            let treeVisitor = TreeRendererVisitor()
            
            let threats = tree.accept(visitor: secVisitor)
            let stats = tree.accept(visitor: statsVisitor)
            let checksum = tree.accept(visitor: checksumVisitor)
            let asciiTree = tree.accept(visitor: treeVisitor)
            
            XCTAssertTrue(threats.isEmpty)
            XCTAssertEqual(stats.totalFiles, 5)
            XCTAssertNotEqual(checksum.crc32, 0)
            XCTAssertFalse(asciiTree.isEmpty)
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5.0)
    }
    
    func testSecurityScannerIntegrationWithCore() {
        let tree = createSampleArchiveTree()
        let result = SecurityScanner.shared.scanComponent(tree)
        XCTAssertTrue(result.isSafe)
        XCTAssertTrue(result.suspiciousFileNames.isEmpty)
    }
    
    func testFolderStatsCalculatorIntegrationWithCore() {
        let tree = createSampleArchiveTree()
        let (size, subfolders, files, dist) = FolderStatsCalculator.calculateStats(for: tree)
        
        XCTAssertEqual(files, 5)
        XCTAssertEqual(subfolders, 3)
        XCTAssertEqual(size, 1024 + 2048 + 4096 + 8192 + 1_048_576)
        XCTAssertFalse(dist.isEmpty)
    }
    
    @MainActor
    func testNativeArchiveOutlineViewTreePreviewIntegration() {
        let node1 = ArchiveTreeNode(id: "1", name: "Doc.txt", path: "Doc.txt", uncompressedSize: 100, isDirectory: false)
        let node2 = ArchiveTreeNode(id: "2", name: "Sub", path: "Sub", uncompressedSize: 0, isDirectory: true, children: [
            ArchiveTreeNode(id: "3", name: "File.png", path: "Sub/File.png", uncompressedSize: 200, isDirectory: false)
        ])
        
        let binding = Binding<String?>(get: { nil }, set: { _ in })
        
        let outlineView = NativeArchiveOutlineView(nodes: [node1, node2], selectedPath: binding) { _ in }
        let previewText = outlineView.renderTreePreview()
        
        XCTAssertTrue(previewText.contains("Doc.txt"))
        XCTAssertTrue(previewText.contains("Sub/"))
        XCTAssertTrue(previewText.contains("File.png"))
    }
}
