// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import Combine

#if MAS_BUILD
/// Mac App Store (MAS) sandbox build: updates managed by App Store.
@MainActor
public final class UpdateManager: ObservableObject {
    public static let shared = UpdateManager()
    
    @Published public var canCheckForUpdates: Bool = false
    
    private init() {}
    
    public func checkForUpdates() {
        // Managed by Mac App Store
    }
}
#else
/// Direct independent distribution channel: integrates Sparkle 2.0 automatic updater.
import Sparkle

@MainActor
public final class UpdateManager: NSObject, ObservableObject, SPUUpdaterDelegate {
    public static let shared = UpdateManager()
    
    @Published public var canCheckForUpdates: Bool = false
    
    private var updaterController: SPUStandardUpdaterController?
    
    private override init() {
        super.init()
        let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
        self.updaterController = controller
        self.canCheckForUpdates = controller.updater.canCheckForUpdates
    }
    
    public func checkForUpdates() {
        updaterController?.checkForUpdates(self)
    }
}
#endif
