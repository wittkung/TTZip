// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import CTTZipBridge
@testable import TTZipCore

private func customXORForward(src: UnsafePointer<UInt8>?, dst: UnsafeMutablePointer<UInt8>?, size: Int, typeSize: UInt8, meta: UInt8) -> Int32 {
    guard let src = src, let dst = dst else { return -1 }
    let key: UInt8 = meta > 0 ? meta : 0x5A
    for i in 0..<size {
        dst[i] = src[i] ^ key
    }
    return 0
}

private func customXORBackward(src: UnsafePointer<UInt8>?, dst: UnsafeMutablePointer<UInt8>?, size: Int, typeSize: UInt8, meta: UInt8) -> Int32 {
    guard let src = src, let dst = dst else { return -1 }
    let key: UInt8 = meta > 0 ? meta : 0x5A
    for i in 0..<size {
        dst[i] = src[i] ^ key
    }
    return 0
}

final class Blosc2PluginRegistryTests: XCTestCase {

    func testDynamicFilterPluginRegistrationAndDispatch() {
        var plugin = ttzip_filter_plugin_t(
            id: 170, // In user range [160, 255]
            name: ("custom_xor_filter" as NSString).utf8String,
            forward: customXORForward,
            backward: customXORBackward
        )

        let regRet = ttzip_plugin_register_filter(&plugin)
        XCTAssertEqual(regRet, 0, "Plugin registration must succeed for ID 170")

        let inputString = "TTZip High-Performance Plugin Registry Payload 2026"
        let inputData = inputString.data(using: .utf8)!
        var encodedData = Data(count: inputData.count)
        var decodedData = Data(count: inputData.count)

        // 1. Dispatch Forward
        let fwdRet = inputData.withUnsafeBytes { rawIn in
            encodedData.withUnsafeMutableBytes { rawOut in
                ttzip_plugin_dispatch_filter_forward(
                    170,
                    rawIn.bindMemory(to: UInt8.self).baseAddress!,
                    rawOut.bindMemory(to: UInt8.self).baseAddress!,
                    inputData.count,
                    1,
                    0x7F // Custom XOR Key
                )
            }
        }
        XCTAssertEqual(fwdRet, 0)
        XCTAssertNotEqual(encodedData, inputData)

        // 2. Dispatch Backward
        let bwdRet = encodedData.withUnsafeBytes { rawIn in
            decodedData.withUnsafeMutableBytes { rawOut in
                ttzip_plugin_dispatch_filter_backward(
                    170,
                    rawIn.bindMemory(to: UInt8.self).baseAddress!,
                    rawOut.bindMemory(to: UInt8.self).baseAddress!,
                    inputData.count,
                    1,
                    0x7F
                )
            }
        }
        XCTAssertEqual(bwdRet, 0)
        XCTAssertEqual(decodedData, inputData, "Custom XOR plugin must restore original bytes losslessly")
    }

    func testInvalidPluginIDRejection() {
        var invalidPlugin = ttzip_filter_plugin_t(
            id: 15, // Out of user range (< 160)
            name: ("invalid_filter" as NSString).utf8String,
            forward: customXORForward,
            backward: customXORBackward
        )

        let regRet = ttzip_plugin_register_filter(&invalidPlugin)
        XCTAssertEqual(regRet, -1, "Registering built-in ID range must be rejected")
    }
}
