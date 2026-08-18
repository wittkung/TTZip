// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Targeted benchmark filter configuration structure.
public struct TargetedBenchmarkFilter: Codable, Sendable {
    public enum TargetAction: String, Codable, Sendable {
        case extractionOnly = "extraction"
        case compressionOnly = "compression"
        case both = "both"
    }

    public struct TargetCase: Codable, Sendable {
        public let pk_idx: Int?
        public let payload: String?
        public let format: String?
        public let level: Int?
        public let encryption: String?
        public let test_target: String?
        public let skip_compress: Bool?
        
        public init(
            pk_idx: Int? = nil,
            payload: String? = nil,
            format: String? = nil,
            level: Int? = nil,
            encryption: String? = nil,
            test_target: String? = nil,
            skip_compress: Bool? = nil
        ) {
            self.pk_idx = pk_idx
            self.payload = payload
            self.format = format
            self.level = level
            self.encryption = encryption
            self.test_target = test_target
            self.skip_compress = skip_compress
        }
    }
    
    public let description: String?
    public let lagging_count: Int?
    public let target_cases: [TargetCase]?
    
    public init(description: String? = nil, lagging_count: Int? = nil, target_cases: [TargetCase]? = nil) {
        self.description = description
        self.lagging_count = lagging_count
        self.target_cases = target_cases
    }
    
    /// Loads configuration from specified JSON file path.
    public static func load(from path: String) -> TargetedBenchmarkFilter? {
        let expandedPath = (path as NSString).expandingTildeInPath
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: expandedPath)),
              let config = try? JSONDecoder().decode(TargetedBenchmarkFilter.self, from: data) else {
            return nil
        }
        return config
    }
    
    /// Matches specific test case.
    public func matchCase(pkIdx: Int, payload: String, format: String, level: Int, encryption: String) -> TargetCase? {
        guard let cases = target_cases, !cases.isEmpty else { return nil }
        return cases.first { tc in
            if let idx = tc.pk_idx, idx > 0, idx == pkIdx { return true }
            
            var payloadMatch = true
            if let p = tc.payload, !p.isEmpty {
                payloadMatch = payload.contains(p) || p.contains(payload)
            }
            
            var formatMatch = true
            if let f = tc.format, !f.isEmpty {
                formatMatch = format.lowercased() == f.lowercased()
            }
            
            var levelMatch = true
            if let l = tc.level {
                levelMatch = (l == level)
            }
            
            var encMatch = true
            if let e = tc.encryption, !e.isEmpty {
                encMatch = encryption.contains(e) || e.contains(encryption)
            }
            
            return payloadMatch && formatMatch && levelMatch && encMatch
        }
    }
    
    /// Checks whether scenario matches filter.
    public func matches(pkIdx: Int, payload: String, format: String, level: Int, encryption: String) -> Bool {
        guard let cases = target_cases, !cases.isEmpty else { return true }
        return matchCase(pkIdx: pkIdx, payload: payload, format: format, level: level, encryption: encryption) != nil
    }

    /// Evaluates whether competitor compression pass should be skipped.
    public func shouldSkipCompress(pkIdx: Int, payload: String, format: String, level: Int, encryption: String) -> Bool {
        if let tc = matchCase(pkIdx: pkIdx, payload: payload, format: format, level: level, encryption: encryption) {
            return tc.skip_compress ?? (tc.test_target == "extraction")
        }
        return false
    }
}
