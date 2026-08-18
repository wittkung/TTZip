// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class IteratorPatternTests: XCTestCase {
    
    // MARK: - 1. ArrayArchiveIterator 、
    
    func testArrayArchiveIteratorFilteringAndSorting() {
        let now = Date()
        let entries = [
            ArchiveEntry(path: "docs/report.pdf", uncompressedSize: 5000, isDirectory: false, modificationDate: now.addingTimeInterval(-3600)),
            ArchiveEntry(path: "docs/notes.txt", uncompressedSize: 200, isDirectory: false, modificationDate: now.addingTimeInterval(-1800)),
            ArchiveEntry(path: "photos/vacation.jpg", uncompressedSize: 120000, isDirectory: false, modificationDate: now),
            ArchiveEntry(path: "photos/archive.zip", uncompressedSize: 50000, isDirectory: false, modificationDate: now.addingTimeInterval(-7200)),
            ArchiveEntry(path: "system/log.txt", uncompressedSize: 800, isDirectory: false, modificationDate: now.addingTimeInterval(-900))
        ]
        
        // A.
        let txtIterator = ArrayArchiveIterator(entries: entries, extensions: ["txt"])
        XCTAssertEqual(txtIterator.count, 2)
        let txtNames = Set(Array(txtIterator).map { $0.name })
        XCTAssertEqual(txtNames, ["notes.txt", "log.txt"])
        
        // B.
        let sizeIterator = ArrayArchiveIterator(entries: entries, minSize: 500, maxSize: 50000)
        XCTAssertEqual(sizeIterator.count, 3) // pdf(5000), archive(50000), log(800)
        
        // C.
        let regexIterator = ArrayArchiveIterator(entries: entries, regexPattern: "^photos/.*")
        XCTAssertEqual(regexIterator.count, 2)
        
        // D.
        let sortSizeDesc = ArrayArchiveIterator(entries: entries, sortBy: .size, sortOrder: .descending)
        let sortedSizes = Array(sortSizeDesc).map { $0.uncompressedSize }
        XCTAssertEqual(sortedSizes, [120000, 50000, 5000, 800, 200])
        
        // E.
        let slicedIterator = sortSizeDesc.slice(offset: 1, limit: 2)
        XCTAssertEqual(slicedIterator.count, 2)
        let slicedSizes = Array(slicedIterator).map { $0.uncompressedSize }
        XCTAssertEqual(slicedSizes, [50000, 5000])
    }
    
    // MARK: - 2. DFS Pre-order Post-order
    
    func testDFSTraversalPreOrderAndPostOrder() {
        let root = ArchiveCompositeDirectory(name: "Root", path: "Root")
        let dirA = ArchiveCompositeDirectory(name: "DirA", path: "Root/DirA")
        let fileA1 = ArchiveLeafFile(name: "FileA1.txt", path: "Root/DirA/FileA1.txt", sizeBytes: 10)
        let fileA2 = ArchiveLeafFile(name: "FileA2.txt", path: "Root/DirA/FileA2.txt", sizeBytes: 20)
        let fileB = ArchiveLeafFile(name: "FileB.txt", path: "Root/FileB.txt", sizeBytes: 30)
        
        dirA.add(component: fileA1)
        dirA.add(component: fileA2)
        root.add(component: dirA)
        root.add(component: fileB)
        
        // A. DFS Pre-order: Root -> DirA -> FileA1 -> FileA2 -> FileB
        let preOrderIterator = DepthFirstTreeIterator(root: root, order: .preOrder)
        var preOrderPaths: [String] = []
        while let entry = preOrderIterator.next() {
            preOrderPaths.append(entry.path)
        }
        XCTAssertEqual(preOrderPaths, ["Root", "Root/DirA", "Root/DirA/FileA1.txt", "Root/DirA/FileA2.txt", "Root/FileB.txt"])
        
        // B. DFS Post-order: FileA1 -> FileA2 -> DirA -> FileB -> Root
        let postOrderIterator = DepthFirstTreeIterator(root: root, order: .postOrder)
        var postOrderPaths: [String] = []
        while let entry = postOrderIterator.next() {
            postOrderPaths.append(entry.path)
        }
        XCTAssertEqual(postOrderPaths, ["Root/DirA/FileA1.txt", "Root/DirA/FileA2.txt", "Root/DirA", "Root/FileB.txt", "Root"])
    }
    
    // MARK: - 3. BFS
    
    func testBFSTraversalLevelOrder() {
        let root = ArchiveCompositeDirectory(name: "Root", path: "Root")
        let dirA = ArchiveCompositeDirectory(name: "DirA", path: "Root/DirA")
        let fileA1 = ArchiveLeafFile(name: "FileA1.txt", path: "Root/DirA/FileA1.txt", sizeBytes: 10)
        let fileB = ArchiveLeafFile(name: "FileB.txt", path: "Root/FileB.txt", sizeBytes: 30)
        
        dirA.add(component: fileA1)
        root.add(component: dirA)
        root.add(component: fileB)
        
        // BFS Level order: Level 0 (Root) -> Level 1 (DirA, FileB) -> Level 2 (FileA1)
        let bfsIterator = BreadthFirstTreeIterator(root: root)
        var bfsPaths: [String] = []
        while let entry = bfsIterator.next() {
            bfsPaths.append(entry.path)
        }
        XCTAssertEqual(bfsPaths, ["Root", "Root/DirA", "Root/FileB.txt", "Root/DirA/FileA1.txt"])
    }
    
    // MARK: - 4. 1000+
    
    func testExplicitStackDeepDirectoryOverflow() {
        let depth = 1000
        let root = ArchiveCompositeDirectory(name: "dir_0", path: "dir_0")
        var current: ArchiveCompositeDirectory = root
        
        for i in 1...depth {
            let nextDir = ArchiveCompositeDirectory(name: "dir_\(i)", path: "\(current.path)/dir_\(i)")
            current.add(component: nextDir)
            current = nextDir
        }
        let leaf = ArchiveLeafFile(name: "deep_leaf.txt", path: "\(current.path)/deep_leaf.txt", sizeBytes: 100)
        current.add(component: leaf)
        
        // A. DFS Pre-order (1000+ )
        let preOrder = DepthFirstTreeIterator(root: root, order: .preOrder)
        var preCount = 0
        while preOrder.next() != nil {
            preCount += 1
        }
        XCTAssertEqual(preCount, depth + 2) // 1001 个 directory + 1 个 leaf
        
        // B. DFS Post-order (1000+ )
        let postOrder = DepthFirstTreeIterator(root: root, order: .postOrder)
        var postCount = 0
        while postOrder.next() != nil {
            postCount += 1
        }
        XCTAssertEqual(postCount, depth + 2)
        
        // C. BFS
        let bfs = BreadthFirstTreeIterator(root: root)
        var bfsCount = 0
        while bfs.next() != nil {
            bfsCount += 1
        }
        XCTAssertEqual(bfsCount, depth + 2)
    }
    
    // MARK: - 5. Peek Reset
    
    func testPeekAndResetIdempotency() {
        let entries = [
            ArchiveEntry(path: "a.txt", uncompressedSize: 10, isDirectory: false),
            ArchiveEntry(path: "b.txt", uncompressedSize: 20, isDirectory: false),
            ArchiveEntry(path: "c.txt", uncompressedSize: 30, isDirectory: false)
        ]
        
        let iter = ArrayArchiveIterator(entries: entries)
        
        // A. 5 Peek() ：
        let peek1 = iter.peek()
        let peek2 = iter.peek()
        let peek3 = iter.peek()
        XCTAssertEqual(peek1?.path, "a.txt")
        XCTAssertEqual(peek2?.path, "a.txt")
        XCTAssertEqual(peek3?.path, "a.txt")
        
        // B. next()
        let first = iter.next()
        XCTAssertEqual(first?.path, "a.txt")
        XCTAssertEqual(iter.peek()?.path, "b.txt")
        
        // C. Skip 1
        let skipped = iter.skip(count: 1)
        XCTAssertEqual(skipped, 1)
        XCTAssertEqual(iter.peek()?.path, "c.txt")
        
        // D. Reset
        iter.reset()
        XCTAssertEqual(iter.peek()?.path, "a.txt")
        XCTAssertEqual(iter.next()?.path, "a.txt")
    }
    
    // MARK: - 6. LazyDiskScanner
    
    func testLazyDiskScannerIterator() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // 10 (.txt .log)
        for i in 1...5 {
            let txtFile = tempDir.appendingPathComponent("file_\(i).txt")
            try "Hello \(i)".write(to: txtFile, atomically: true, encoding: .utf8)
            let logFile = tempDir.appendingPathComponent("file_\(i).log")
            try "Log \(i)".write(to: logFile, atomically: true, encoding: .utf8)
        }
        
        // ： .txt
        let lazyScanner = LazyDiskScannerIterator(
            rootURL: tempDir,
            urlPredicate: { $0.pathExtension == "txt" }
        )
        
        var txtCount = 0
        while let entry = lazyScanner.next() {
            XCTAssertTrue(entry.path.hasSuffix(".txt"))
            txtCount += 1
        }
        XCTAssertEqual(txtCount, 5)
        
        // Reset
        lazyScanner.reset()
        XCTAssertFalse(lazyScanner.isAtEnd)
        XCTAssertTrue(lazyScanner.peek()?.path.hasSuffix(".txt") ?? false)
    }
    
    // MARK: - 7. Swift Sequence
    
    func testSwiftSequenceChainingConformances() {
        let entries = [
            ArchiveEntry(path: "src/main.swift", uncompressedSize: 1500, isDirectory: false),
            ArchiveEntry(path: "src/utils.swift", uncompressedSize: 800, isDirectory: false),
            ArchiveEntry(path: "assets/logo.png", uncompressedSize: 50000, isDirectory: false)
        ]
        
        let rootComponent = ArchiveComponentTreeBuilder.buildTree(from: entries)
        
        // A. ArchiveCompositeDirectory Sequence filter / map / reduce
        let totalSize = rootComponent.filter { !$0.isDirectory }.reduce(0) { $0 + $1.uncompressedSize }
        XCTAssertEqual(totalSize, 52300)
        
        let swiftFiles = rootComponent.filter { $0.path.hasSuffix(".swift") }.map { $0.name }
        XCTAssertEqual(Set(swiftFiles), ["main.swift", "utils.swift"])
        
        // B. ArchiveTreeNode Sequence
        let treeNodes = ArchiveTreeBuilder.buildTree(from: entries)
        let rootNode = ArchiveTreeNode(
            id: "root",
            name: "root",
            path: "",
            uncompressedSize: 52300,
            isDirectory: true,
            children: treeNodes
        )
        let treeLeafPaths = rootNode.filter { !$0.isDirectory }.map { $0.path }
        XCTAssertEqual(treeLeafPaths.count, 3)
        
        // C. ArchiveInspectionResult Sequence
        let dummyReport = SecurityReport(
            isSafe: true,
            suspiciousFileNames: [],
            hasZipSlipRisk: false,
            detailMessage: "Pass",
            riskLevel: .safe
        )
        let inspectionResult = ArchiveInspectionResult(
            archivePath: "test.zip",
            entries: entries,
            treeNode: rootComponent,
            securityReport: dummyReport
        )
        
        let inspectionNames = inspectionResult.map { $0.name }
        XCTAssertEqual(inspectionNames, ["main.swift", "utils.swift", "logo.png"])
    }
    
    // MARK: - 8. 100+
    
    func testConcurrentIterationThreadSafety() async {
        let entries = (0..<100).map { i in
            ArchiveEntry(path: "items/file_\(i).txt", uncompressedSize: Int64(i * 10), isDirectory: false)
        }
        
        let arrayIter = ArrayArchiveIterator(entries: entries)
        let root = ArchiveComponentTreeBuilder.buildTree(from: entries)
        let dfsIter = DepthFirstTreeIterator(root: root, order: .preOrder)
        let bfsIter = BreadthFirstTreeIterator(root: root)
        
        await withTaskGroup(of: Void.self) { group in
            for taskIdx in 0..<120 {
                group.addTask {
                    if taskIdx % 4 == 0 {
                        _ = arrayIter.peek()
                        _ = arrayIter.next()
                    } else if taskIdx % 4 == 1 {
                        _ = dfsIter.peek()
                        _ = dfsIter.next()
                    } else if taskIdx % 4 == 2 {
                        _ = bfsIter.peek()
                        _ = bfsIter.next()
                    } else {
                        arrayIter.reset()
                        dfsIter.reset()
                        bfsIter.reset()
                    }
                }
            }
        }
        
        XCTAssertNotNil(arrayIter)
        XCTAssertNotNil(dfsIter)
        XCTAssertNotNil(bfsIter)
    }
    
    // MARK: - 9. ： Mutation Safety
    
    func testTreeDynamicMutationSafetyDuringIteration() {
        let root = ArchiveCompositeDirectory(name: "Root", path: "Root")
        let dirA = ArchiveCompositeDirectory(name: "DirA", path: "Root/DirA")
        let fileA1 = ArchiveLeafFile(name: "FileA1.txt", path: "Root/DirA/FileA1.txt", sizeBytes: 10)
        let fileA2 = ArchiveLeafFile(name: "FileA2.txt", path: "Root/DirA/FileA2.txt", sizeBytes: 20)
        
        dirA.add(component: fileA1)
        dirA.add(component: fileA2)
        root.add(component: dirA)
        
        // A. DFS Pre-order
        let dfsPre = DepthFirstTreeIterator(root: root, order: .preOrder)
        var preVisited: [String] = []
        while let entry = dfsPre.next() {
            preVisited.append(entry.path)
            if entry.path == "Root/DirA" {
                // FileA1， FileA3
                dirA.remove(componentNamed: "FileA1.txt")
                let fileA3 = ArchiveLeafFile(name: "FileA3.txt", path: "Root/DirA/FileA3.txt", sizeBytes: 30)
                dirA.add(component: fileA3)
            }
        }
        XCTAssertFalse(preVisited.isEmpty)
        
        // B. DFS Post-order Composite
        let dfsPost = DepthFirstTreeIterator(root: root, order: .postOrder)
        var postVisited: [String] = []
        while let entry = dfsPost.next() {
            postVisited.append(entry.path)
            if entry.path == "Root/DirA/FileA2.txt" {
                dirA.removeAll()
            }
        }
        XCTAssertFalse(postVisited.isEmpty)
        
        // C. BFS
        let bfs = BreadthFirstTreeIterator(root: root)
        var bfsVisited: [String] = []
        while let entry = bfs.next() {
            bfsVisited.append(entry.path)
            if entry.path == "Root" {
                let dirB = ArchiveCompositeDirectory(name: "DirB", path: "Root/DirB")
                root.add(component: dirB)
            }
        }
        XCTAssertFalse(bfsVisited.isEmpty)
    }
    
    // MARK: - 10. ：LazyDiskScanner / Cleanup
    
    func testLazyDiskScannerEarlyTerminationCleanup() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        for i in 1...20 {
            let file = tempDir.appendingPathComponent("data_\(i).bin")
            try "bin \(i)".write(to: file, atomically: true, encoding: .utf8)
        }
        
        // A. for-in break ， close()
        let scanner = LazyDiskScannerIterator(rootURL: tempDir)
        var count = 0
        for entry in scanner {
            _ = entry
            count += 1
            if count == 5 {
                scanner.close() // 手动触发显式句柄彻底销毁
                break
            }
        }
        XCTAssertEqual(count, 5)
        XCTAssertTrue(scanner.isAtEnd)
        
        // B. ， enumerator nil
        let fullScanner = LazyDiskScannerIterator(rootURL: tempDir)
        var total = 0
        while fullScanner.next() != nil {
            total += 1
        }
        XCTAssertEqual(total, 20)
        XCTAssertTrue(fullScanner.isAtEnd)
    }
    
    // MARK: - 11. ：100+ ArrayArchiveIterator
    
    func testArrayArchiveIteratorExhaustive100PlusThreadsConcurrency() async {
        let entries = (0..<500).map { i in
            ArchiveEntry(path: "dir/file_\(i).dat", uncompressedSize: Int64(i * 100), isDirectory: false)
        }
        
        let iterator = ArrayArchiveIterator(entries: entries)
        
        await withTaskGroup(of: Void.self) { group in
            for threadId in 0..<150 {
                group.addTask {
                    let op = threadId % 6
                    switch op {
                    case 0:
                        _ = iterator.next()
                    case 1:
                        _ = iterator.peek()
                    case 2:
                        iterator.reset()
                    case 3:
                        _ = iterator.skip(count: 10)
                    case 4:
                        _ = iterator.slice(offset: threadId, limit: 20)
                    case 5:
                        _ = iterator.isAtEnd
                        _ = iterator.count
                    default:
                        break
                    }
                }
            }
        }
        
        XCTAssertGreaterThan(iterator.count, 0)
    }
    
    // MARK: - 12. ：100+ LazyDiskScanner
    
    func testLazyDiskScannerHighConcurrencyStressTest() async {
        guard let tempDir = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else { return }
        
        let scanner = LazyDiskScannerIterator(rootURL: tempDir)
        
        await withTaskGroup(of: Void.self) { group in
            for threadId in 0..<100 {
                group.addTask {
                    let op = threadId % 5
                    switch op {
                    case 0:
                        _ = scanner.next()
                    case 1:
                        _ = scanner.peek()
                    case 2:
                        _ = scanner.isAtEnd
                    case 3:
                        _ = scanner.skip(count: 3)
                    case 4:
                        scanner.reset()
                    default:
                        break
                    }
                }
            }
        }
        
        scanner.close()
        XCTAssertTrue(scanner.isAtEnd)
    }
    
    // MARK: - 13. ：LazyDiskScanner 150+ close /next /peek /reset ARC deinit
    
    func testRound3LazyDiskScannerConcurrentTokenDeinitAndCloseSafety() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        for i in 1...50 {
            let f = tempDir.appendingPathComponent("file_\(i).tmp")
            try "data \(i)".write(to: f, atomically: true, encoding: .utf8)
        }
        
        // 150+ / /
        await withTaskGroup(of: Void.self) { group in
            for threadId in 0..<150 {
                group.addTask {
                    let scanner = LazyDiskScannerIterator(rootURL: tempDir)
                    let op = threadId % 7
                    switch op {
                    case 0:
                        _ = scanner.next()
                        scanner.close()
                    case 1:
                        _ = scanner.peek()
                        _ = scanner.next()
                    case 2:
                        _ = scanner.skip(count: 10)
                        scanner.close()
                    case 3:
                        scanner.reset()
                        _ = scanner.isAtEnd
                    case 4:
                        _ = scanner.next()
                        scanner.reset()
                        scanner.close()
                    case 5:
                        _ = scanner.count
                        scanner.close()
                    case 6:
                        _ = scanner.peek()
                        scanner.close()
                        _ = scanner.next()
                    default:
                        break
                    }
                    // scanner deinit
                }
            }
        }
    }
    
    // MARK: - 14. ：10,000+ Sequence filter/map/reduce O 1 Init
    
    func testRound3Large10kEntriesSequenceHighOrderFunctionsPerformanceAndMemory() {
        let entryCount = 10_000
        var entries: [ArchiveEntry] = []
        entries.reserveCapacity(entryCount)
        
        for i in 0..<entryCount {
            let isDir = (i % 10 == 0)
            let path = isDir ? "dir_\(i / 10)" : "dir_\(i / 10)/file_\(i).txt"
            entries.append(ArchiveEntry(
                path: path,
                uncompressedSize: Int64(i * 100),
                isDirectory: isDir
            ))
        }
        
        // A. ArchiveInspectionResult Sequence filter / map / reduce
        let rootComponent = ArchiveComponentTreeBuilder.buildTree(from: entries)
        let report = SecurityReport(isSafe: true, suspiciousFileNames: [], hasZipSlipRisk: false, detailMessage: "OK", riskLevel: .safe)
        let inspectionResult = ArchiveInspectionResult(archivePath: "large10k.zip", entries: entries, treeNode: rootComponent, securityReport: report)
        
        let start = CFAbsoluteTimeGetCurrent()
        let totalSize = inspectionResult
            .filter { !$0.isDirectory }
            .reduce(0) { $0 + $1.uncompressedSize }
        let duration = CFAbsoluteTimeGetCurrent() - start
        
        XCTAssertGreaterThan(totalSize, 0)
        XCTAssertLessThan(duration, 0.5, "10,000 条目 Sequence 链式 reduce 耗时超标: \(duration)s")
        
        // B. Composite DFS / BFS O(1)
        let initStart = CFAbsoluteTimeGetCurrent()
        let dfsIter = rootComponent.makeDepthFirstIterator(order: .preOrder)
        let bfsIter = rootComponent.makeBreadthFirstIterator()
        let initDuration = CFAbsoluteTimeGetCurrent() - initStart
        
        XCTAssertLessThan(initDuration, 0.01, "DFS/BFS Iterator 初始化耗时应为 O(1): \(initDuration)s")
        
        // Verify expected invariant
        let filteredFiles = dfsIter.filter { !$0.isDirectory }
        XCTAssertGreaterThan(filteredFiles.count, 8000)
        XCTAssertEqual(bfsIter.count, rootComponent.totalFileCount() + rootComponent.totalDirectoryCount() + 1)
    }
    
    // MARK: - 15. ：MillerColumnDirectoryScanner & CLICommandRouter
    
    func testRound3MillerColumnScannerAndCLIRouterStreamingAccuracy() async throws {
        let entries = [
            ArchiveEntry(path: "documents/work/report.pdf", uncompressedSize: 5000, isDirectory: false),
            ArchiveEntry(path: "documents/work/notes.txt", uncompressedSize: 1000, isDirectory: false),
            ArchiveEntry(path: "documents/personal/photo.jpg", uncompressedSize: 20000, isDirectory: false),
            ArchiveEntry(path: "readme.txt", uncompressedSize: 500, isDirectory: false)
        ]
        
        let rootComponent = ArchiveComponentTreeBuilder.buildTree(from: entries)
        
        // A. CLI renderTree ASCII
        let treeStr = rootComponent.renderTree()
        XCTAssertTrue(treeStr.contains("documents (<DIR>)"))
        XCTAssertTrue(treeStr.contains("work (<DIR>)"))
        XCTAssertTrue(treeStr.contains("report.pdf"))
        XCTAssertTrue(treeStr.contains("readme.txt"))
        
        // B. Iterator
        let iterator = ArrayArchiveIterator(entries: entries)
        var printedLines: [String] = []
        while let entry = iterator.next() {
            let sizeStr = entry.isDirectory ? "<DIR>" : "\(entry.uncompressedSize) B"
            let p = entry.path.padding(toLength: 30, withPad: " ", startingAt: 0)
            printedLines.append("\(p) | \(sizeStr)")
        }
        
        XCTAssertEqual(printedLines.count, 4)
        XCTAssertTrue(printedLines[0].contains("documents/work/report.pdf"))
        XCTAssertTrue(printedLines[3].contains("readme.txt"))
    }
}

