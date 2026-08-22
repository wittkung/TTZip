// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Platform hardware thermal state coordinator and DVFS debounce scheduler (Swift 6 Isolated Actor).
public actor HardwareThermalCoordinator {
    public static let shared = HardwareThermalCoordinator()
    private init() {}

    private var isMonitoring: Bool = false
    private var monitorTask: Task<Void, Never>?

    public var currentThermalState: ProcessInfo.ThermalState {
        return ProcessInfo.processInfo.thermalState
    }

    /// Starts background thermal state observer (non-blocking AsyncSequence stream).
    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        monitorTask = Task.detached(priority: .utility) { [weak self] in
            let notifications = NotificationCenter.default.notifications(
                named: ProcessInfo.thermalStateDidChangeNotification,
                object: nil
            )
            for await _ in notifications {
                let state = ProcessInfo.processInfo.thermalState
                await self?.handleThermalStateChange(state)
            }
        }
    }

    /// Stops thermal state monitoring.
    public func stopMonitoring() {
        isMonitoring = false
        monitorTask?.cancel()
        monitorTask = nil
    }

    private func handleThermalStateChange(_ state: ProcessInfo.ThermalState) {
        // Internal state synchronization hook
    }

    /// Performs adaptive hardware cooldown wait if thermal throttling pressure is high.
    /// - Parameter maxWaitSeconds: Maximum cooldown timeout limit in seconds.
    /// - Returns: Boolean indicating whether cooldown pause was triggered.
    @discardableResult
    public func performAdaptiveCooldownIfNeeded(maxWaitSeconds: Double = 30.0) async -> Bool {
        let state = ProcessInfo.processInfo.thermalState
        guard state == .serious || state == .critical else {
            return false
        }

        let startNanos = PlatformMonotonicTimer.nowNanoseconds()
        let maxWaitNanos = UInt64(maxWaitSeconds * 1_000_000_000)

        // Poll until thermal state recovers to .nominal or timeout expires
        while ProcessInfo.processInfo.thermalState != .nominal {
            let elapsed = PlatformMonotonicTimer.nowNanoseconds() - startNanos
            if elapsed >= maxWaitNanos {
                break
            }
            try? await Task.sleep(nanoseconds: 500_000_000) // Poll every 500ms
        }

        // Additional 1.5s post-nominal stabilization delay for DVFS frequency settling
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        return true
    }
}
