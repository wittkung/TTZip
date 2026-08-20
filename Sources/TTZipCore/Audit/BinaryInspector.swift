// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.

import Foundation

public struct BinarySectionSnapshot: Sendable, Codable {
    public let binaryPath: String
    public let rawSizeBytes: Int
    public let strippedSizeBytes: Int
    public let textSectionBytes: Int
    public let dataSectionBytes: Int
    public let bssSectionBytes: Int
    public let exportedSymbols: [String]

    public init(
        binaryPath: String,
        rawSizeBytes: Int,
        strippedSizeBytes: Int,
        textSectionBytes: Int,
        dataSectionBytes: Int,
        bssSectionBytes: Int,
        exportedSymbols: [String]
    ) {
        self.binaryPath = binaryPath
        self.rawSizeBytes = rawSizeBytes
        self.strippedSizeBytes = strippedSizeBytes
        self.textSectionBytes = textSectionBytes
        self.dataSectionBytes = dataSectionBytes
        self.bssSectionBytes = bssSectionBytes
        self.exportedSymbols = exportedSymbols
    }
}

public struct BinaryDeltaReport: Sendable, Codable {
    public let targetName: String
    public let baseRawSizeBytes: Int
    public let headRawSizeBytes: Int
    public let rawDeltaBytes: Int
    public let rawDeltaPercent: Double
    public let baseStrippedSizeBytes: Int
    public let headStrippedSizeBytes: Int
    public let strippedDeltaBytes: Int
    public let strippedDeltaPercent: Double
    public let textDeltaBytes: Int
    public let dataDeltaBytes: Int
    public let bssDeltaBytes: Int
    public let addedSymbols: [String]
    public let removedSymbols: [String]

    public init(
        targetName: String,
        baseRawSizeBytes: Int,
        headRawSizeBytes: Int,
        rawDeltaBytes: Int,
        rawDeltaPercent: Double,
        baseStrippedSizeBytes: Int,
        headStrippedSizeBytes: Int,
        strippedDeltaBytes: Int,
        strippedDeltaPercent: Double,
        textDeltaBytes: Int,
        dataDeltaBytes: Int,
        bssDeltaBytes: Int,
        addedSymbols: [String],
        removedSymbols: [String]
    ) {
        self.targetName = targetName
        self.baseRawSizeBytes = baseRawSizeBytes
        self.headRawSizeBytes = headRawSizeBytes
        self.rawDeltaBytes = rawDeltaBytes
        self.rawDeltaPercent = rawDeltaPercent
        self.baseStrippedSizeBytes = baseStrippedSizeBytes
        self.headStrippedSizeBytes = headStrippedSizeBytes
        self.strippedDeltaBytes = strippedDeltaBytes
        self.strippedDeltaPercent = strippedDeltaPercent
        self.textDeltaBytes = textDeltaBytes
        self.dataDeltaBytes = dataDeltaBytes
        self.bssDeltaBytes = bssDeltaBytes
        self.addedSymbols = addedSymbols
        self.removedSymbols = removedSymbols
    }
}

public final class BinaryInspector: Sendable {
    public static let shared = BinaryInspector()
    public init() {}

    private func runCommand(_ launchPath: String, _ args: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }

    private func resolveTool(_ name: String) -> String {
        if let env = ProcessInfo.processInfo.environment[name.uppercased() + "_BIN"], FileManager.default.fileExists(atPath: env) {
            return env
        }
        for prefix in ["/usr/bin", "/usr/local/bin", "/opt/homebrew/bin", "/usr/bin"] {
            let path = "\(prefix)/\(name)"
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return "/usr/bin/\(name)"
    }

    public func inspect(binaryPath: String) -> BinarySectionSnapshot {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: binaryPath) else {
            return BinarySectionSnapshot(
                binaryPath: binaryPath,
                rawSizeBytes: 0,
                strippedSizeBytes: 0,
                textSectionBytes: 0,
                dataSectionBytes: 0,
                bssSectionBytes: 0,
                exportedSymbols: []
            )
        }

        let rawSize = (try? fileManager.attributesOfItem(atPath: binaryPath)[.size] as? Int) ?? 0

        // Stripped size via temporary copy
        var strippedSize = rawSize
        let tempStrippedPath = NSTemporaryDirectory() + "ttzip_strip_\(UUID().uuidString)"
        if (try? fileManager.copyItem(atPath: binaryPath, toPath: tempStrippedPath)) != nil {
            let stripTool = resolveTool("strip")
            _ = runCommand(stripTool, ["-x", tempStrippedPath])
            strippedSize = (try? fileManager.attributesOfItem(atPath: tempStrippedPath)[.size] as? Int) ?? rawSize
            try? fileManager.removeItem(atPath: tempStrippedPath)
        }

        // Section analysis via size -m (Darwin) or size (Linux)
        var textBytes = 0
        var dataBytes = 0
        var bssBytes = 0

        let sizeTool = resolveTool("size")
        let sizeOut = runCommand(sizeTool, ["-m", binaryPath])
        if !sizeOut.isEmpty {
            let lines = sizeOut.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("Section __text:") {
                    let parts = trimmed.components(separatedBy: ":")
                    if parts.count >= 2, let num = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
                        textBytes = num
                    }
                } else if trimmed.hasPrefix("Section __data:") {
                    let parts = trimmed.components(separatedBy: ":")
                    if parts.count >= 2, let num = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
                        dataBytes = num
                    }
                } else if trimmed.hasPrefix("Section __bss:") {
                    let parts = trimmed.components(separatedBy: ":")
                    if parts.count >= 2, let num = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
                        bssBytes = num
                    }
                }
            }
        }

        // Exported symbols via nm -gU
        var symbols: [String] = []
        let nmTool = resolveTool("nm")
        let nmOut = runCommand(nmTool, ["-gU", binaryPath])
        if !nmOut.isEmpty {
            let lines = nmOut.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }
                let parts = trimmed.components(separatedBy: " ")
                if let last = parts.last, !last.isEmpty {
                    symbols.append(last)
                }
            }
        }
        symbols.sort()

        return BinarySectionSnapshot(
            binaryPath: binaryPath,
            rawSizeBytes: rawSize,
            strippedSizeBytes: strippedSize,
            textSectionBytes: textBytes,
            dataSectionBytes: dataBytes,
            bssSectionBytes: bssBytes,
            exportedSymbols: symbols
        )
    }

    public func diff(base: BinarySectionSnapshot, head: BinarySectionSnapshot, targetName: String) -> BinaryDeltaReport {
        let rawDelta = head.rawSizeBytes - base.rawSizeBytes
        let rawPct = base.rawSizeBytes > 0 ? (Double(rawDelta) / Double(base.rawSizeBytes)) * 100.0 : 0.0

        let stripDelta = head.strippedSizeBytes - base.strippedSizeBytes
        let stripPct = base.strippedSizeBytes > 0 ? (Double(stripDelta) / Double(base.strippedSizeBytes)) * 100.0 : 0.0

        let textDelta = head.textSectionBytes - base.textSectionBytes
        let dataDelta = head.dataSectionBytes - base.dataSectionBytes
        let bssDelta = head.bssSectionBytes - base.bssSectionBytes

        let baseSet = Set(base.exportedSymbols)
        let headSet = Set(head.exportedSymbols)

        let added = headSet.subtracting(baseSet).sorted()
        let removed = baseSet.subtracting(headSet).sorted()

        return BinaryDeltaReport(
            targetName: targetName,
            baseRawSizeBytes: base.rawSizeBytes,
            headRawSizeBytes: head.rawSizeBytes,
            rawDeltaBytes: rawDelta,
            rawDeltaPercent: rawPct,
            baseStrippedSizeBytes: base.strippedSizeBytes,
            headStrippedSizeBytes: head.strippedSizeBytes,
            strippedDeltaBytes: stripDelta,
            strippedDeltaPercent: stripPct,
            textDeltaBytes: textDelta,
            dataDeltaBytes: dataDelta,
            bssDeltaBytes: bssDelta,
            addedSymbols: added,
            removedSymbols: removed
        )
    }
}
