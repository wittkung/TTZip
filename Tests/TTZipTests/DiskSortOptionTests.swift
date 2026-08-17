import XCTest
@testable import TTZipApp
@testable import TTZipCore

final class DiskSortOptionTests: XCTestCase {
    
    // MARK: - Test Fixture Helper
    
    private func createItem(
        name: String,
        isDirectory: Bool = false,
        size: Int64 = 1024,
        date: Date? = nil,
        kind: String = "文本文件",
        path: String? = nil
    ) -> DiskItemInfo {
        let actualPath = path ?? "/test/\(name)"
        return DiskItemInfo(
            virtualName: name,
            virtualURL: URL(fileURLWithPath: actualPath),
            isDirectory: isDirectory,
            isArchive: false,
            sizeText: "\(size) B",
            rawSizeBytes: size,
            kindText: kind,
            modificationDate: date
        )
    }
    
    // MARK: - Phase 1 & 2: Date Sorting Tests (T003)
    
    func testDateDescendingSorting() {
        let baseDate = Date(timeIntervalSince1970: 1700000000)
        let olderDate = baseDate.addingTimeInterval(-86400)
        let newestDate = baseDate.addingTimeInterval(86400)
        
        let folder = createItem(name: "FolderA", isDirectory: true, date: baseDate)
        let itemOld = createItem(name: "OldFile.txt", date: olderDate)
        let itemMid = createItem(name: "MidFile.txt", date: baseDate)
        let itemNew = createItem(name: "NewFile.txt", date: newestDate)
        let itemNil = createItem(name: "NilDateFile.txt", date: nil)
        
        let unsorted = [itemOld, itemNil, folder, itemNew, itemMid]
        let sorted = DiskItemSorter.sort(unsorted, by: .dateDesc)
        
        // Folders always first, then newest to oldest, then nil dates
        XCTAssertEqual(sorted.map(\.name), ["FolderA", "NewFile.txt", "MidFile.txt", "OldFile.txt", "NilDateFile.txt"])
    }
    
    func testDateAscendingSorting() {
        let baseDate = Date(timeIntervalSince1970: 1700000000)
        let olderDate = baseDate.addingTimeInterval(-86400)
        let newestDate = baseDate.addingTimeInterval(86400)
        
        let folder = createItem(name: "FolderA", isDirectory: true, date: baseDate)
        let itemOld = createItem(name: "OldFile.txt", date: olderDate)
        let itemMid = createItem(name: "MidFile.txt", date: baseDate)
        let itemNew = createItem(name: "NewFile.txt", date: newestDate)
        let itemNil = createItem(name: "NilDateFile.txt", date: nil)
        
        let unsorted = [itemNew, folder, itemMid, itemNil, itemOld]
        let sorted = DiskItemSorter.sort(unsorted, by: .dateAsc)
        
        // Folders always first, then oldest to newest, then nil dates
        XCTAssertEqual(sorted.map(\.name), ["FolderA", "OldFile.txt", "MidFile.txt", "NewFile.txt", "NilDateFile.txt"])
    }
    
    func testDateSortingWithIdenticalDatesTieBreaker() {
        let sameDate = Date(timeIntervalSince1970: 1700000000)
        let itemB = createItem(name: "B.txt", date: sameDate)
        let itemA = createItem(name: "A.txt", date: sameDate)
        let itemC = createItem(name: "C.txt", date: sameDate)
        
        let sortedDesc = DiskItemSorter.sort([itemB, itemC, itemA], by: .dateDesc)
        XCTAssertEqual(sortedDesc.map(\.name), ["A.txt", "B.txt", "C.txt"])
        
        let sortedAsc = DiskItemSorter.sort([itemC, itemB, itemA], by: .dateAsc)
        XCTAssertEqual(sortedAsc.map(\.name), ["A.txt", "B.txt", "C.txt"])
    }
    
    // MARK: - Phase 3: Size & Kind Sorting Tests (T006)
    
    func testSizeDescendingSorting() {
        let folder = createItem(name: "Folder", isDirectory: true, size: 0)
        let small = createItem(name: "small.txt", size: 100)
        let medium = createItem(name: "medium.txt", size: 5000)
        let large = createItem(name: "large.txt", size: 100000)
        let zero1 = createItem(name: "zeroB.txt", size: 0)
        let zero2 = createItem(name: "zeroA.txt", size: 0)
        
        let unsorted = [small, folder, large, zero1, zero2, medium]
        let sorted = DiskItemSorter.sort(unsorted, by: .sizeDesc)
        
        // Folder first, then 100000 -> 5000 -> 100 -> 0 (with name tie-breaker: zeroA before zeroB)
        XCTAssertEqual(sorted.map(\.name), ["Folder", "large.txt", "medium.txt", "small.txt", "zeroA.txt", "zeroB.txt"])
    }
    
    func testSizeAscendingSorting() {
        let folder = createItem(name: "Folder", isDirectory: true, size: 0)
        let small = createItem(name: "small.txt", size: 100)
        let medium = createItem(name: "medium.txt", size: 5000)
        let large = createItem(name: "large.txt", size: 100000)
        let zero1 = createItem(name: "zeroB.txt", size: 0)
        let zero2 = createItem(name: "zeroA.txt", size: 0)
        
        let unsorted = [large, small, zero1, folder, zero2, medium]
        let sorted = DiskItemSorter.sort(unsorted, by: .sizeAsc)
        
        // Folder first, then 0 (zeroA, zeroB) -> 100 -> 5000 -> 100000
        XCTAssertEqual(sorted.map(\.name), ["Folder", "zeroA.txt", "zeroB.txt", "small.txt", "medium.txt", "large.txt"])
    }
    
    func testKindSorting() {
        let folder = createItem(name: "Folder", isDirectory: true, kind: "文件夹")
        let archZ = createItem(name: "archiveZ.zip", kind: "ZIP 归档")
        let archA = createItem(name: "archiveA.7z", kind: "7Z 归档")
        let pdf = createItem(name: "document.pdf", kind: "PDF 文档")
        let textB = createItem(name: "textB.txt", kind: "文本文件")
        let textA = createItem(name: "textA.txt", kind: "文本文件")
        
        let unsorted = [textB, archZ, folder, textA, pdf, archA]
        let sorted = DiskItemSorter.sort(unsorted, by: .kind)
        
        // Folders first
        XCTAssertEqual(sorted.first?.name, "Folder")
        let fileNames = sorted.dropFirst().map(\.name)
        // Verified localizedStandardCompare order: "7Z 归档" -> "文本文件" (textA, textB) -> "PDF 文档" -> "ZIP 归档"
        XCTAssertEqual(fileNames, ["archiveA.7z", "textA.txt", "textB.txt", "document.pdf", "archiveZ.zip"])
    }
    
    func testAsciiKindSorting() {
        let itemC = createItem(name: "c.txt", kind: "Image PNG")
        let itemB = createItem(name: "b.txt", kind: "Document PDF")
        let itemA = createItem(name: "a.txt", kind: "Archive ZIP")
        let itemA2 = createItem(name: "a2.txt", kind: "Archive ZIP")
        
        let sorted = DiskItemSorter.sort([itemC, itemB, itemA, itemA2], by: .kind)
        XCTAssertEqual(sorted.map(\.name), ["a.txt", "a2.txt", "b.txt", "c.txt"])
    }
    
    // MARK: - Phase 4: Name Sorting & Natural Numeric Ordering Tests (T009)
    
    func testNaturalNumericNameAscending() {
        let folder2 = createItem(name: "folder 2", isDirectory: true)
        let folder10 = createItem(name: "folder 10", isDirectory: true)
        let file1 = createItem(name: "file1.txt")
        let file2 = createItem(name: "file2.txt")
        let file10 = createItem(name: "file10.txt")
        let file20 = createItem(name: "file20.txt")
        let file100 = createItem(name: "file100.txt")
        
        let unsorted = [file100, file2, folder10, file10, file1, folder2, file20]
        let sorted = DiskItemSorter.sort(unsorted, by: .nameAsc)
        
        XCTAssertEqual(sorted.map(\.name), [
            "folder 2", "folder 10",
            "file1.txt", "file2.txt", "file10.txt", "file20.txt", "file100.txt"
        ])
    }
    
    func testNaturalNumericNameDescending() {
        let folder2 = createItem(name: "folder 2", isDirectory: true)
        let folder10 = createItem(name: "folder 10", isDirectory: true)
        let file1 = createItem(name: "file1.txt")
        let file2 = createItem(name: "file2.txt")
        let file10 = createItem(name: "file10.txt")
        let file100 = createItem(name: "file100.txt")
        
        let unsorted = [file1, file100, folder2, file2, folder10, file10]
        let sorted = DiskItemSorter.sort(unsorted, by: .nameDesc)
        
        XCTAssertEqual(sorted.map(\.name), [
            "folder 10", "folder 2",
            "file100.txt", "file10.txt", "file2.txt", "file1.txt"
        ])
    }
    
    // MARK: - Phase 5: View Delegation & Edge Cases (T014)
    
    func testEmptyAndSingleItemCollections() {
        let empty: [DiskItemInfo] = []
        XCTAssertEqual(DiskItemSorter.sort(empty, by: .nameAsc).count, 0)
        XCTAssertEqual(DiskItemSorter.sort(empty, by: .dateDesc).count, 0)
        
        let single = [createItem(name: "single.txt")]
        XCTAssertEqual(DiskItemSorter.sort(single, by: .nameAsc).map(\.name), ["single.txt"])
        XCTAssertEqual(DiskItemSorter.sort(single, by: .sizeDesc).map(\.name), ["single.txt"])
    }
    
    func testDiskDirectoryBrowserViewDelegation() {
        let item1 = createItem(name: "b.txt")
        let item2 = createItem(name: "a.txt")
        let sorted = DiskDirectoryBrowserView.sortItems([item1, item2], option: .nameAsc)
        XCTAssertEqual(sorted.map(\.name), ["a.txt", "b.txt"])
    }
    
    // MARK: - Advanced Mathematical & Edge Case Invariants
    
    func testFoldersAlwaysPrecedeFilesAcrossAllSortOptions() {
        let folder1 = createItem(name: "z_folder", isDirectory: true, size: 0, date: Date(timeIntervalSince1970: 100))
        let folder2 = createItem(name: "a_folder", isDirectory: true, size: 0, date: Date(timeIntervalSince1970: 900))
        let file1 = createItem(name: "a_file.txt", isDirectory: false, size: 10000, date: Date(timeIntervalSince1970: 1000))
        let file2 = createItem(name: "z_file.txt", isDirectory: false, size: 10, date: Date(timeIntervalSince1970: 50))
        
        let unsorted = [file1, folder1, file2, folder2]
        
        for opt in DiskSortOption.allCases {
            let sorted = DiskItemSorter.sort(unsorted, by: opt)
            XCTAssertTrue(sorted[0].isDirectory, "First item under \(opt) must be a directory")
            XCTAssertTrue(sorted[1].isDirectory, "Second item under \(opt) must be a directory")
            XCTAssertFalse(sorted[2].isDirectory, "Third item under \(opt) must be a file")
            XCTAssertFalse(sorted[3].isDirectory, "Fourth item under \(opt) must be a file")
        }
    }
    
    func testAllNilDatesTieBreaksByName() {
        let itemC = createItem(name: "c.txt", date: nil)
        let itemA = createItem(name: "a.txt", date: nil)
        let itemB = createItem(name: "b.txt", date: nil)
        
        let sortedDesc = DiskItemSorter.sort([itemC, itemA, itemB], by: .dateDesc)
        XCTAssertEqual(sortedDesc.map(\.name), ["a.txt", "b.txt", "c.txt"])
        
        let sortedAsc = DiskItemSorter.sort([itemC, itemA, itemB], by: .dateAsc)
        XCTAssertEqual(sortedAsc.map(\.name), ["a.txt", "b.txt", "c.txt"])
    }
    
    func testIdenticalNameAndSizeDifferentPathTieBreaksByPath() {
        let item2 = createItem(name: "dup.txt", size: 100, path: "/virtual/dirB/dup.txt")
        let item1 = createItem(name: "dup.txt", size: 100, path: "/virtual/dirA/dup.txt")
        
        let sorted = DiskItemSorter.sort([item2, item1], by: .sizeDesc)
        XCTAssertEqual(sorted.map(\.path), ["file:///virtual/dirA/dup.txt", "file:///virtual/dirB/dup.txt"])
    }
    
    func testStrictWeakOrderingProperties() {
        let a = createItem(name: "a.txt", size: 100, date: Date(timeIntervalSince1970: 100))
        let b = createItem(name: "b.txt", size: 200, date: Date(timeIntervalSince1970: 200))
        let c = createItem(name: "c.txt", size: 300, date: Date(timeIntervalSince1970: 300))
        
        for opt in DiskSortOption.allCases {
            // 1. Irreflexivity: !(a < a)
            XCTAssertFalse(DiskItemSorter.isOrderedBefore(a, a, option: opt))
            XCTAssertFalse(DiskItemSorter.isOrderedBefore(b, b, option: opt))
            XCTAssertFalse(DiskItemSorter.isOrderedBefore(c, c, option: opt))
            
            // 2. Asymmetry: a < b => !(b < a)
            let ab = DiskItemSorter.isOrderedBefore(a, b, option: opt)
            let ba = DiskItemSorter.isOrderedBefore(b, a, option: opt)
            XCTAssertFalse(ab && ba, "Asymmetry violation for \(opt)")
            
            // 3. Transitivity: a < b and b < c => a < c (for sizeAsc)
            if opt == .sizeAsc {
                XCTAssertTrue(DiskItemSorter.isOrderedBefore(a, b, option: opt))
                XCTAssertTrue(DiskItemSorter.isOrderedBefore(b, c, option: opt))
                XCTAssertTrue(DiskItemSorter.isOrderedBefore(a, c, option: opt))
            }
        }
    }
}

