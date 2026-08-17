// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Represents the high-level semantic user action decoded from terminal raw byte streams.
public enum TUIKeyAction: Sendable, Equatable {
    case up
    case down
    case left
    case right
    case enter
    case space
    case peek
    case extract
    case exit
    case pageUp
    case pageDown
    case home
    case end
    case unknown
}

/// ANSI multi-byte escape sequence and Vim keybinding decoder for interactive terminal sessions.
public enum TUIKeyParser: Sendable {
    
    /// Parses a sequence of raw bytes received from STDIN into a semantic `TUIKeyAction`.
    /// - Parameter bytes: The raw byte array read from terminal input.
    /// - Returns: Decoded `TUIKeyAction`.
    public static func parse(bytes: [UInt8]) -> TUIKeyAction {
        guard !bytes.isEmpty else { return .unknown }
        
        // Single byte ASCII / control keys
        if bytes.count == 1 {
            switch bytes[0] {
            case 0x1B: // Standalone Escape
                return .exit
            case 0x03: // Ctrl+C
                return .exit
            case 0x04: // Ctrl+D
                return .pageDown
            case 0x0D, 0x0A: // Enter (\r or \n)
                return .enter
            case 0x20: // Spacebar
                return .space
            case UInt8(ascii: "k"), UInt8(ascii: "K"):
                return .up
            case UInt8(ascii: "j"), UInt8(ascii: "J"):
                return .down
            case UInt8(ascii: "h"), UInt8(ascii: "H"):
                return .left
            case UInt8(ascii: "l"), UInt8(ascii: "L"):
                return .right
            case UInt8(ascii: "e"), UInt8(ascii: "E"):
                return .extract
            case UInt8(ascii: "p"), UInt8(ascii: "P"):
                return .peek
            case UInt8(ascii: "q"), UInt8(ascii: "Q"):
                return .exit
            default:
                return .unknown
            }
        }
        
        // Multi-byte ANSI escape sequences (starting with ESC 0x1B)
        if bytes[0] == 0x1B {
            if bytes.count >= 3 && bytes[1] == 0x5B { // CSI: \u{1B}[
                switch bytes[2] {
                case 0x41: return .up       // \e[A (Up Arrow)
                case 0x42: return .down     // \e[B (Down Arrow)
                case 0x43: return .right    // \e[C (Right Arrow)
                case 0x44: return .left     // \e[D (Left Arrow)
                case 0x48: return .home     // \e[H (Home)
                case 0x46: return .end      // \e[F (End)
                case 0x31: return .home     // \e[1~ (Home)
                case 0x34: return .end      // \e[4~ (End)
                case 0x35: return .pageUp   // \e[5~ (Page Up)
                case 0x36: return .pageDown // \e[6~ (Page Down)
                default: break
                }
            } else if bytes.count >= 3 && bytes[1] == 0x4F { // SS3: \u{1B}O
                switch bytes[2] {
                case 0x41: return .up       // \eOA (Up Arrow)
                case 0x42: return .down     // \eOB (Down Arrow)
                case 0x43: return .right    // \eOC (Right Arrow)
                case 0x44: return .left     // \eOD (Left Arrow)
                case 0x48: return .home     // \eOH (Home)
                case 0x46: return .end      // \eOF (End)
                default: break
                }
            }
        }
        
        return .unknown
    }
}
