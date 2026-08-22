// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore

/// Dynamic shell auto-completion script generator.
///
/// Derives production-ready Zsh, Bash, Fish, and Nushell completion scripts dynamically
/// from `CLICommandSpec` as the single source of truth.
public enum ShellCompletionGenerator {
    
    /// Generates completion script for the targeted shell.
    public static func generate(
        for shell: ShellTarget,
        binaryName: String = "ttzip-cli",
        includeAliases: Bool = true
    ) -> String {
        switch shell {
        case .zsh:
            return generateZsh(binaryName: binaryName, includeAliases: includeAliases)
        case .bash:
            return generateBash(binaryName: binaryName, includeAliases: includeAliases)
        case .fish:
            return generateFish(binaryName: binaryName, includeAliases: includeAliases)
        case .nushell:
            return generateNushell(binaryName: binaryName, includeAliases: includeAliases)
        }
    }
}
