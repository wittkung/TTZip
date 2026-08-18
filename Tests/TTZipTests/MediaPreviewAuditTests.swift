// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import AppKit
import AVFoundation
import ImageIO
import CoreGraphics
@testable import TTZipCore
@testable import TTZipApp

final class MediaPreviewAuditTests: XCTestCase {
    
    private var tempDirURL: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirURL = FileManager.default.temporaryDirectory.appendingPathComponent("MediaPreviewAudit_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        if let url = tempDirURL {
            try? FileManager.default.removeItem(at: url)
        }
        try super.tearDownWithError()
    }
    
    // MARK: - Test 1: Image Downsampling Reduces 50MP Mock Image
    
    func testImageDownsamplingReduces50MPMockImagePixelDimensions() throws {
        // 1. 50MP (8000 x 6250 = 50,000,000 pixels)
        let width = 8000
        let height = 6250
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            XCTFail("无法创建 50MP 测试位图上下文")
            return
        }
        
        context.setFillColor(CGColor(red: 0.2, green: 0.7, blue: 0.4, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let cgImage50MP = context.makeImage() else {
            XCTFail("无法生成 50MP CGImage")
            return
        }
        
        // 2. JPEG /
        let jpegData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(jpegData as CFMutableData, "public.jpeg" as CFString, 1, nil) else {
            XCTFail("无法创建 CGImageDestination")
            return
        }
        CGImageDestinationAddImage(destination, cgImage50MP, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination), "JPEG 编码导出失败")
        
        let fileURL = tempDirURL.appendingPathComponent("sample_50mp.jpg")
        try (jpegData as Data).write(to: fileURL)
        
        // 3. ImageIO ( maxPixelSize: 2048)
        let cache = ImageIOThumbnailCache.shared
        guard let downsampledDataImage = cache.downsample(data: jpegData as Data, maxPixelSize: 2048) else {
            XCTFail("从 Data 执行 ImageIO 下采样失败")
            return
        }
        
        guard let downsampledFileURLImage = cache.downsample(url: fileURL, maxPixelSize: 2048) else {
            XCTFail("从 URL 执行 ImageIO 下采样失败")
            return
        }
        
        // 4. <= 2048px，
        guard let cgData = downsampledDataImage.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let cgFile = downsampledFileURLImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            XCTFail("无法提取下采样后的底层 CGImage")
            return
        }
        
        XCTAssertLessThanOrEqual(cgData.width, 2048, "Data 下采样宽度超过 2048px")
        XCTAssertLessThanOrEqual(cgData.height, 2048, "Data 下采样高度超过 2048px")
        XCTAssertEqual(cgData.width, 2048, "主轴宽度应严格约束为 2048px")
        XCTAssertEqual(cgData.height, 1600, "副轴高度应保持 8000:6250 等比缩小至 1600px")
        
        XCTAssertLessThanOrEqual(cgFile.width, 2048, "File URL 下采样宽度超过 2048px")
        XCTAssertLessThanOrEqual(cgFile.height, 2048, "File URL 下采样高度超过 2048px")
    }
    
    // MARK: - Test 2: ImageIOThumbnailCache Hit/Miss Behavior & Thread Safety
    
    func testImageIOThumbnailCacheHitMissAndThreadSafety() throws {
        let cache = ImageIOThumbnailCache.shared
        cache.purgeCache()
        cache.resetStatistics()
        
        // 1.
        let testImageURL = tempDirURL.appendingPathComponent("test_cache.png")
        let dummyContext = CGContext(
            data: nil,
            width: 100,
            height: 100,
            bitsPerComponent: 8,
            bytesPerRow: 400,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        dummyContext.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        dummyContext.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        let img = dummyContext.makeImage()!
        
        let rep = NSBitmapImageRep(cgImage: img)
        let pngData = rep.representation(using: .png, properties: [:])!
        try pngData.write(to: testImageURL)
        
        // 2. ： Cache Miss
        let first = cache.thumbnail(for: testImageURL, maxPixelSize: 512)
        XCTAssertNotNil(first)
        XCTAssertEqual(cache.missCount, 1)
        XCTAssertEqual(cache.hitCount, 0)
        
        // 3. ： Cache Hit
        let second = cache.thumbnail(for: testImageURL, maxPixelSize: 512)
        XCTAssertNotNil(second)
        XCTAssertEqual(cache.missCount, 1)
        XCTAssertEqual(cache.hitCount, 1)
        
        // 4. (50 )
        let group = DispatchGroup()
        let iterations = 50
        
        for _ in 0..<iterations {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                let cached = cache.thumbnail(for: testImageURL, maxPixelSize: 512)
                XCTAssertNotNil(cached)
                group.leave()
            }
        }
        
        group.wait()
        XCTAssertEqual(cache.missCount, 1)
        XCTAssertEqual(cache.hitCount, 1 + iterations)
    }
    
    // MARK: - Test 3: Audio/Video Store Teardown Lifecycle
    
    @MainActor
    func testAudioVideoStoreTeardownLifecycle() throws {
        let store = SharedVideoPlayerStore()
        
        // Verify expected invariant
        let testMediaURL = tempDirURL.appendingPathComponent("mock_video.mp4")
        try Data("mock media stream content".utf8).write(to: testMediaURL)
        
        // 1.
        store.setup(url: testMediaURL)
        XCTAssertNotNil(store.player)
        XCTAssertEqual(store.currentURL, testMediaURL)
        
        // 2.
        store.togglePlayPause()
        XCTAssertTrue(store.isPlaying)
        
        // 3. 5
        store.cleanUp()
        
        // 4.
        XCTAssertNil(store.player, "Player 实例未置为 nil")
        XCTAssertNil(store.currentURL, "currentURL 未清空")
        XCTAssertFalse(store.isPlaying, "isPlaying 状态未重置")
        XCTAssertEqual(store.currentTime, 0, "currentTime 未清零")
        XCTAssertEqual(store.duration, 0, "duration 未清零")
        
        // 5. AVPlayer replaceCurrentItem(with: nil)
        let directPlayer = AVPlayer(url: testMediaURL)
        XCTAssertNotNil(directPlayer.currentItem)
        directPlayer.replaceCurrentItem(with: nil)
        XCTAssertNil(directPlayer.currentItem, "AVPlayerItem 未成功置空解绑")
    }
    
    // MARK: - Test 4: Drag Provider Virtual Item Metadata
    
    @MainActor
    func testDragProviderWrapsVirtualItemMetadata() throws {
        // 1. （ PreviewLRUCacheManager ）
        let mockArchivePath = "/Users/test/Documents/archive.zip"
        let mockSubpath = "assets/hero_banner.png"
        let virtualPath = "file://\(mockArchivePath)?subpath=\(mockSubpath)"
        let filename = "hero_banner.png"
        
        let hash = abs(mockArchivePath.hashValue).description + "_" + abs(filename.hashValue).description
        let targetCachedURL = PreviewLRUCacheManager.shared.targetURL(forKey: hash, filename: filename)
        
        // Verify expected invariant
        let dummyData = Data("mock extracted png image".utf8)
        try dummyData.write(to: targetCachedURL)
        PreviewLRUCacheManager.shared.register(key: hash, fileURL: targetCachedURL)
        
        let cachedItem = DiskItemInfo(
            virtualName: filename,
            virtualURL: URL(string: virtualPath)!,
            isDirectory: false,
            isArchive: false,
            sizeText: "1.2 MB",
            rawSizeBytes: 1200000,
            kindText: "PNG 图像"
        )
        
        let cachedProvider = MillerColumnItemRowView.makeDragItemProvider(for: cachedItem)
        XCTAssertEqual(cachedProvider.suggestedName, filename, "已缓存虚拟项拖拽 suggestedName 不匹配")
        XCTAssertTrue(cachedProvider.canLoadObject(ofClass: URL.self), "Drag provider 应支持加载 URL 对象")
        
        // 2. （ ）
        let uncachedVirtualPath = "file://\(mockArchivePath)?subpath=docs/manual.pdf"
        let uncachedItem = DiskItemInfo(
            virtualName: "manual.pdf",
            virtualURL: URL(string: uncachedVirtualPath)!,
            isDirectory: false,
            isArchive: false,
            sizeText: "500 KB",
            rawSizeBytes: 500000,
            kindText: "PDF 文档"
        )
        
        let uncachedProvider = MillerColumnItemRowView.makeDragItemProvider(for: uncachedItem)
        XCTAssertEqual(uncachedProvider.suggestedName, "manual.pdf", "未缓存虚拟项拖拽 suggestedName 不匹配")
        
        // 3.
        let physicalFile = tempDirURL.appendingPathComponent("regular_document.txt")
        try "hello ttzip".write(to: physicalFile, atomically: true, encoding: .utf8)
        
        let physicalItem = DiskItemInfo(url: physicalFile)
        let physicalProvider = MillerColumnItemRowView.makeDragItemProvider(for: physicalItem)
        XCTAssertEqual(physicalProvider.suggestedName, "regular_document.txt", "物理文件拖拽 suggestedName 不匹配")
    }
}
