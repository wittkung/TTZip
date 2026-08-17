import Foundation
import AppKit
import ImageIO
import CoreGraphics

/// 高性能 ImageIO 图像下采样与享元缩略图缓存中枢 (Zero-Copy CoreGraphics Thumbnail Cache)
public final class ImageIOThumbnailCache: @unchecked Sendable {
    public static let shared = ImageIOThumbnailCache()
    
    private let cache = NSCache<NSString, NSImage>()
    private let lock = NSLock()
    
    private(set) public var hitCount: Int = 0
    private(set) public var missCount: Int = 0
    
    public init(countLimit: Int = 200, totalCostLimitMB: Int = 128) {
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimitMB * 1024 * 1024
    }
    
    /// 获取指定 URL 的下采样缩略图（优先命中内存缓存）
    public func thumbnail(for url: URL, maxPixelSize: CGFloat = 2048) -> NSImage? {
        let key = "\(url.path)_\(Int(maxPixelSize))" as NSString
        
        lock.lock()
        if let cached = cache.object(forKey: key) {
            hitCount += 1
            lock.unlock()
            return cached
        }
        missCount += 1
        lock.unlock()
        
        guard let downsampled = downsample(url: url, maxPixelSize: maxPixelSize) else {
            return nil
        }
        
        lock.lock()
        let cost = Int(downsampled.size.width * downsampled.size.height * 4)
        cache.setObject(downsampled, forKey: key, cost: cost)
        lock.unlock()
        
        return downsampled
    }

    /// 同步获取缩略图别名方法
    public func getThumbnail(for url: URL, maxPixelSize: CGFloat = 2048) -> NSImage? {
        return thumbnail(for: url, maxPixelSize: maxPixelSize)
    }

    /// 异步获取缩略图
    public func getThumbnailAsync(for url: URL, maxPixelSize: CGFloat = 2048) async -> NSImage? {
        return thumbnail(for: url, maxPixelSize: maxPixelSize)
    }
    
    /// 从文件 URL 直接执行零中间位图分配的 CoreGraphics 下采样
    public func downsample(url: URL, maxPixelSize: CGFloat = 2048) -> NSImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else {
            return nil
        }
        return createThumbnail(from: imageSource, maxPixelSize: maxPixelSize)
    }
    
    /// 从内存 Data 直接执行零中间位图分配的 CoreGraphics 下采样
    public func downsample(data: Data, maxPixelSize: CGFloat = 2048) -> NSImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }
        return createThumbnail(from: imageSource, maxPixelSize: maxPixelSize)
    }
    
    private func createThumbnail(from imageSource: CGImageSource, maxPixelSize: CGFloat) -> NSImage? {
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let thumbnailCGImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions as CFDictionary) else {
            return nil
        }
        let size = NSSize(width: thumbnailCGImage.width, height: thumbnailCGImage.height)
        return NSImage(cgImage: thumbnailCGImage, size: size)
    }
    
    /// 重置缓存统计计数
    public func resetStatistics() {
        lock.lock()
        hitCount = 0
        missCount = 0
        lock.unlock()
    }
    
    /// 清空全部缩略图缓存
    public func purgeCache() {
        lock.lock()
        cache.removeAllObjects()
        hitCount = 0
        missCount = 0
        lock.unlock()
    }
}
