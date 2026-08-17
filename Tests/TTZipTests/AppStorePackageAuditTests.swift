// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Foundation

final class AppStorePackageAuditTests: XCTestCase {
    
    private var repoRoot: URL {
        let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        if FileManager.default.fileExists(atPath: currentDir.appendingPathComponent("Package.swift").path) {
            return currentDir
        }
        return URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
    
    func testPrivacyInfoManifestCompliance() throws {
        let privacyFile = repoRoot.appendingPathComponent("Sources/TTZipApp/PrivacyInfo.xcprivacy")
        XCTAssertTrue(FileManager.default.fileExists(atPath: privacyFile.path), "PrivacyInfo.xcprivacy 必须存在于 Sources/TTZipApp/")
        
        let data = try Data(contentsOf: privacyFile)
        guard let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            XCTFail("PrivacyInfo.xcprivacy 必须是有效的 Apple Property List")
            return
        }
        
        // 1. 验证零用户追踪
        let tracking = plist["NSPrivacyTracking"] as? Bool
        XCTAssertEqual(tracking, false, "TTZip 绝无用户行为追踪 (NSPrivacyTracking 必须为 false)")
        
        // 2. 验证零用户数据收集
        let collected = plist["NSPrivacyCollectedDataTypes"] as? [Any]
        XCTAssertNotNil(collected)
        XCTAssertTrue(collected?.isEmpty == true, "TTZip 绝无用户数据上传或收集 (NSPrivacyCollectedDataTypes 必须为空)")
        
        // 3. 验证声明的敏感 API 理由
        let accessedAPIs = plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]]
        XCTAssertNotNil(accessedAPIs)
        XCTAssertTrue(accessedAPIs?.contains { ($0["NSPrivacyAccessedAPIType"] as? String) == "NSPrivacyAccessedAPICategoryFileTimestamp" } == true, "必须合法声明归档时间戳访问理由")
    }
    
    func testAppSandboxEntitlementsCompliance() throws {
        let entitlementsFile = repoRoot.appendingPathComponent("Sources/TTZipApp/TTZip.entitlements")
        XCTAssertTrue(FileManager.default.fileExists(atPath: entitlementsFile.path), "TTZip.entitlements 必须存在")
        
        let data = try Data(contentsOf: entitlementsFile)
        guard let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            XCTFail("TTZip.entitlements 必须是有效的 Property List")
            return
        }
        
        XCTAssertEqual(plist["com.apple.security.app-sandbox"] as? Bool, true, "MAS 构建必须开启 App Sandbox")
        XCTAssertEqual(plist["com.apple.security.files.user-selected.read-write"] as? Bool, true, "必须请求用户选取文件读写权限")
        XCTAssertEqual(plist["com.apple.security.files.bookmarks.app-scope"] as? Bool, true, "必须开启安全作用域书签")
    }
    
    func testInfoPlistFormatAndUTICoverage() throws {
        let infoPlistFile = repoRoot.appendingPathComponent("Sources/TTZipApp/Info.plist")
        XCTAssertTrue(FileManager.default.fileExists(atPath: infoPlistFile.path), "Info.plist 必须存在")
        
        let data = try Data(contentsOf: infoPlistFile)
        guard let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            XCTFail("Info.plist 必须是有效的 Property List")
            return
        }
        
        XCTAssertEqual(plist["CFBundleExecutable"] as? String, "TTZip")
        XCTAssertEqual(plist["CFBundleIdentifier"] as? String, "com.metastudyline.ttzip")
        XCTAssertEqual(plist["CFBundlePackageType"] as? String, "APPL")
        XCTAssertEqual(plist["LSApplicationCategoryType"] as? String, "public.app-category.utilities")
        
        guard let docTypes = plist["CFBundleDocumentTypes"] as? [[String: Any]],
              let firstType = docTypes.first,
              let extensions = firstType["CFBundleTypeExtensions"] as? [String] else {
            XCTFail("CFBundleDocumentTypes 必须定义支持的扩展名列表")
            return
        }
        
        let requiredFormats = ["zip", "7z", "tar", "gz", "bz2", "xz", "zst", "lz4", "lzip", "wim", "dmg", "iso", "rar", "001"]
        for fmt in requiredFormats {
            XCTAssertTrue(extensions.contains(fmt), "Info.plist 必须声明支持 .\(fmt) 归档扩展名")
        }
    }
    
    func testAppIconICNSAssetExists() {
        let iconFile = repoRoot.appendingPathComponent("Sources/TTZipApp/Resources/AppIcon.icns")
        XCTAssertTrue(FileManager.default.fileExists(atPath: iconFile.path), "AppIcon.icns 资源文件必须存在")
        let attrs = try? FileManager.default.attributesOfItem(atPath: iconFile.path)
        let size = attrs?[.size] as? Int64 ?? 0
        XCTAssertGreaterThan(size, 10000, "AppIcon.icns 必须包含完整的各分辨率图层")
    }
}
