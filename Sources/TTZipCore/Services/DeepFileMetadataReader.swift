// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import ImageIO
import AVFoundation

/// Deep EXIF, media hardware stream attributes, and POSIX permissions inspection service.
public final class DeepFileMetadataReader: @unchecked Sendable {
    nonisolated public static func readMetadata(for url: URL) async -> [String: String] {
        var dict: [String: String] = [:]
        let path = url.path
        let ext = url.pathExtension.lowercased()
        let fm = FileManager.default
        
        // 1. POSIX permissions & APFS attributes
        if let attr = try? fm.attributesOfItem(atPath: path) {
            if let posix = attr[.posixPermissions] as? NSNumber {
                dict["POSIX Permissions"] = String(format: "%04o", posix.uint16Value)
            }
            if let owner = attr[.ownerAccountName] as? String, let group = attr[.groupOwnerAccountName] as? String {
                dict["Owner : Group"] = "\(owner) : \(group)"
            }
            if let inode = attr[.systemFileNumber] as? NSNumber {
                dict["APFS Inode"] = "\(inode)"
            }
        }
        
        // 2. Image EXIF, camera optics, and color spaces (CGImageSource)
        if ["jpg", "jpeg", "png", "heic", "webp", "gif", "tiff", "bmp", "raw"].contains(ext) {
            if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
               let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {
                
                if let w = properties[kCGImagePropertyPixelWidth as String],
                   let h = properties[kCGImagePropertyPixelHeight as String] {
                    dict["Dimensions (Pixels)"] = "\(w) × \(h)"
                }
                if let colorModel = properties[kCGImagePropertyColorModel as String] {
                    dict["Color Model"] = "\(colorModel)"
                }
                if let depth = properties[kCGImagePropertyDepth as String] {
                    dict["Bit Depth"] = "\(depth) bit"
                }
                if let profile = properties[kCGImagePropertyProfileName as String] {
                    dict["ICC Profile"] = "\(profile)"
                }
                if let dpiW = properties[kCGImagePropertyDPIWidth as String] {
                    dict["DPI Resolution"] = "\(dpiW) DPI"
                }
                if let hasAlpha = properties[kCGImagePropertyHasAlpha as String] as? Bool {
                    dict["Alpha Channel"] = hasAlpha ? "Yes" : "No"
                }
                
                if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
                    if let iso = (exif[kCGImagePropertyExifISOSpeedRatings as String] as? [Int])?.first {
                        dict["EXIF: ISO Speed"] = "ISO \(iso)"
                    }
                    if let fNumber = exif[kCGImagePropertyExifFNumber as String] {
                        dict["EXIF: F-Number"] = "f/\(fNumber)"
                    }
                    if let expTime = exif[kCGImagePropertyExifExposureTime as String] {
                        dict["EXIF: Exposure Time"] = "\(expTime) s"
                    }
                    if let focal = exif[kCGImagePropertyExifFocalLength as String] {
                        dict["EXIF: Focal Length"] = "\(focal) mm"
                    }
                    if let lens = exif[kCGImagePropertyExifLensModel as String] {
                        dict["EXIF: Lens Model"] = "\(lens)"
                    }
                }
                
                if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
                    if let make = tiff[kCGImagePropertyTIFFMake as String],
                       let model = tiff[kCGImagePropertyTIFFModel as String] {
                        dict["Camera Hardware"] = "\(make) \(model)"
                    }
                }
            }
        }
        
        // 3. Audio & Video media codecs, framerate, and bitrate (AVURLAsset)
        if ["mp4", "mov", "m4v", "mkv", "avi", "webm", "mp3", "wav", "flac", "m4a", "aac"].contains(ext) {
            let asset = AVURLAsset(url: url)
            if let duration = try? await asset.load(.duration) {
                let secs = CMTimeGetSeconds(duration)
                if secs.isFinite && secs > 0 {
                    let m = Int(secs) / 60
                    let s = Int(secs) % 60
                    dict["Total Duration"] = String(format: "%02d:%02d (%.1f s)", m, s, secs)
                }
            }
            
            if let tracks = try? await asset.load(.tracks) {
                for track in tracks {
                    if track.mediaType == .video {
                        if let size = try? await track.load(.naturalSize), size.width > 0 && size.height > 0 {
                            dict["Video Dimensions"] = "\(Int(size.width)) × \(Int(size.height))"
                        }
                        if let rate = try? await track.load(.nominalFrameRate), rate > 0 {
                            dict["Frame Rate (FPS)"] = String(format: "%.2f fps", rate)
                        }
                        if let bitrate = try? await track.load(.estimatedDataRate), bitrate > 0 {
                            dict["Video Bitrate"] = String(format: "%.1f Mbps", Double(bitrate) / 1_000_000.0)
                        }
                    } else if track.mediaType == .audio {
                        if let bitrate = try? await track.load(.estimatedDataRate), bitrate > 0 {
                            dict["Audio Bitrate"] = String(format: "%.0f kbps", Double(bitrate) / 1000.0)
                        }
                    }
                }
            }
        }
        
        return dict
    }
}
