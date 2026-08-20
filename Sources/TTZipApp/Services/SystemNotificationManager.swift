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
        let manager = TTZipLocalizationManager.shared
        let content = UNMutableNotificationContent()
        let titleTemplate = manager.string(for: L10n.Notification.taskCompletedTitle)
        content.title = String(format: titleTemplate, operationType.capitalized)
        
        let formattedSize = ByteSizeFormatter.format(bytes: bytesProcessed, style: .metricSI, language: manager.currentLanguage)
        let bodyTemplate = manager.string(for: L10n.Notification.taskCompletedBody)
        content.body = String(format: bodyTemplate, taskName, formattedSize, durationSeconds)
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
        let manager = TTZipLocalizationManager.shared
        let content = UNMutableNotificationContent()
        content.title = manager.string(for: L10n.Notification.taskFailedTitle)
        let bodyTemplate = manager.string(for: L10n.Notification.taskFailedBody)
        content.body = String(format: bodyTemplate, taskName, errorMessage)
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    /// Posts a security warning notification when a malicious traversal entry is blocked.
    public func postThreatInterceptedNotification(entryPath: String) {
        let manager = TTZipLocalizationManager.shared
        let content = UNMutableNotificationContent()
        content.title = manager.string(for: L10n.Notification.threatInterceptedTitle)
        let bodyTemplate = manager.string(for: L10n.Notification.threatInterceptedBody)
        content.body = String(format: bodyTemplate, entryPath)
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}
