// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import UserNotifications
import TTZipCore

/// Background task completion and disaster notification dispatcher.
public final class SystemNotificationManager: @unchecked Sendable {
    public static let shared = SystemNotificationManager()
    
    private init() {}
    
    /// Requests notification permissions on macOS.
    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let err = error {
                TTLogger.error("Failed to request notification permission: \(err.localizedDescription)")
            }
        }
    }
    
    /// Posts a system banner notification when a long-running compression or extraction finishes.
    public func postTaskCompletedNotification(
        taskName: String,
        operationType: String,
        durationSeconds: Double,
        bytesProcessed: Int64
    ) {
        let content = UNMutableNotificationContent()
        content.title = "\(operationType.capitalized) Completed"
        let formattedSize = ByteCountFormatter.string(fromByteCount: bytesProcessed, countStyle: .file)
        content.body = "\(taskName) (\(formattedSize)) finished in \(String(format: "%.1fs", durationSeconds))"
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Immediate delivery
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let err = error {
                TTLogger.error("Error scheduling task completed notification: \(err.localizedDescription)")
            }
        }
    }
    
    /// Posts an alert notification when a task fails.
    public func postTaskFailedNotification(taskName: String, errorMessage: String) {
        let content = UNMutableNotificationContent()
        content.title = "Operation Failed"
        content.body = "\(taskName): \(errorMessage)"
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}
