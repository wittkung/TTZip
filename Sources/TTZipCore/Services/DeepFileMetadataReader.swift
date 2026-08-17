import Foundation
import ImageIO
import AVFoundation

/// 深层 EXIF、媒体硬件参数与 POSIX 属性提权读取服务
public final class DeepFileMetadataReader: @unchecked Sendable {
    nonisolated public static func readMetadata(for url: URL) async -> [String: String] {
        var dict: [String: String] = [:]
        let path = url.path
        let ext = url.pathExtension.lowercased()
        let fm = FileManager.default
        
        // 1. POSIX 权限与 APFS 文件系统属性
        if let attr = try? fm.attributesOfItem(atPath: path) {
            if let posix = attr[.posixPermissions] as? NSNumber {
                dict["POSIX 权限码"] = String(format: "%04o", posix.uint16Value)
            }
            if let owner = attr[.ownerAccountName] as? String, let group = attr[.groupOwnerAccountName] as? String {
                dict["所有者 : 用户组"] = "\(owner) : \(group)"
            }
            if let inode = attr[.systemFileNumber] as? NSNumber {
                dict["APFS Inode 编号"] = "\(inode)"
            }
        }
        
        // 2. 图像 EXIF、相机参数与色彩空间 (CGImageSource)
        if ["jpg", "jpeg", "png", "heic", "webp", "gif", "tiff", "bmp", "raw"].contains(ext) {
            if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
               let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {
                
                if let w = properties[kCGImagePropertyPixelWidth as String],
                   let h = properties[kCGImagePropertyPixelHeight as String] {
                    dict["画面尺寸 (Pixels)"] = "\(w) × \(h)"
                }
                if let colorModel = properties[kCGImagePropertyColorModel as String] {
                    dict["色彩模型 (Model)"] = "\(colorModel)"
                }
                if let depth = properties[kCGImagePropertyDepth as String] {
                    dict["通道位深 (Depth)"] = "\(depth) bit"
                }
                if let profile = properties[kCGImagePropertyProfileName as String] {
                    dict["ICC 色彩配置文件"] = "\(profile)"
                }
                if let dpiW = properties[kCGImagePropertyDPIWidth as String] {
                    dict["DPI 精细度"] = "\(dpiW) DPI"
                }
                if let hasAlpha = properties[kCGImagePropertyHasAlpha as String] as? Bool {
                    dict["Alpha 透明通道"] = hasAlpha ? "包含 (Yes)" : "无 (No)"
                }
                
                if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
                    if let iso = (exif[kCGImagePropertyExifISOSpeedRatings as String] as? [Int])?.first {
                        dict["EXIF: ISO 感光度"] = "ISO \(iso)"
                    }
                    if let fNumber = exif[kCGImagePropertyExifFNumber as String] {
                        dict["EXIF: 光圈值"] = "f/\(fNumber)"
                    }
                    if let expTime = exif[kCGImagePropertyExifExposureTime as String] {
                        dict["EXIF: 快门速度"] = "\(expTime) 秒"
                    }
                    if let focal = exif[kCGImagePropertyExifFocalLength as String] {
                        dict["EXIF: 焦距"] = "\(focal) mm"
                    }
                    if let lens = exif[kCGImagePropertyExifLensModel as String] {
                        dict["EXIF: 镜头型号"] = "\(lens)"
                    }
                }
                
                if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
                    if let make = tiff[kCGImagePropertyTIFFMake as String],
                       let model = tiff[kCGImagePropertyTIFFModel as String] {
                        dict["相机设备型号"] = "\(make) \(model)"
                    }
                }
            }
        }
        
        // 3. 音视频媒体编码、帧率与码率 (AVURLAsset)
        if ["mp4", "mov", "m4v", "mkv", "avi", "webm", "mp3", "wav", "flac", "m4a", "aac"].contains(ext) {
            let asset = AVURLAsset(url: url)
            if let duration = try? await asset.load(.duration) {
                let secs = CMTimeGetSeconds(duration)
                if secs.isFinite && secs > 0 {
                    let m = Int(secs) / 60
                    let s = Int(secs) % 60
                    dict["总时长"] = String(format: "%02d:%02d (%.1f 秒)", m, s, secs)
                }
            }
            
            if let tracks = try? await asset.load(.tracks) {
                for track in tracks {
                    if track.mediaType == .video {
                        if let size = try? await track.load(.naturalSize), size.width > 0 && size.height > 0 {
                            dict["视频尺寸"] = "\(Int(size.width)) × \(Int(size.height))"
                        }
                        if let rate = try? await track.load(.nominalFrameRate), rate > 0 {
                            dict["帧率 (FPS)"] = String(format: "%.2f fps", rate)
                        }
                        if let bitrate = try? await track.load(.estimatedDataRate), bitrate > 0 {
                            dict["视频码率"] = String(format: "%.1f Mbps", Double(bitrate) / 1_000_000.0)
                        }
                    } else if track.mediaType == .audio {
                        if let bitrate = try? await track.load(.estimatedDataRate), bitrate > 0 {
                            dict["音频码率"] = String(format: "%.0f kbps", Double(bitrate) / 1000.0)
                        }
                    }
                }
            }
        }
        
        return dict
    }
}
