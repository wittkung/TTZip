// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import LocalAuthentication

/// macOS Touch ID / Apple Watch biometric authenticator for Password Vault protection.
public final class TouchIDAuthenticator: @unchecked Sendable {
    public static let shared = TouchIDAuthenticator()
    
    private init() {}
    
    /// Checks if device supports biometric or Apple Watch authentication.
    public func canEvaluateBiometrics() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            || context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }
    
    /// Evaluates biometric authentication asynchronously on MainActor / background thread.
    public func authenticate(reason: String = "Unlock TTZip Password Vault") async -> (success: Bool, error: String?) {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        
        var authError: NSError?
        let policy: LAPolicy = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError)
            ? .deviceOwnerAuthenticationWithBiometrics
            : .deviceOwnerAuthentication
        
        do {
            let success = try await context.evaluatePolicy(policy, localizedReason: reason)
            return (success, nil)
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .appCancel:
                return (false, "Authentication was cancelled")
            case .biometryNotEnrolled:
                return (false, "Touch ID is not enrolled on this Mac")
            case .biometryLockout:
                return (false, "Touch ID is locked out due to too many failed attempts")
            default:
                return (false, error.localizedDescription)
            }
        } catch {
            return (false, error.localizedDescription)
        }
    }
}
