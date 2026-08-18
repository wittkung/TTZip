// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI

/// Global fluid animation state ensuring cross-view fluid phase coherence.
@MainActor
public final class TTZipGlobalFluidState {
    public static let shared = TTZipGlobalFluidState()
    
    private var phase: Double = Double.random(in: 0...100)
    private var lastTime: Double = CACurrentMediaTime()
    
    private init() {}
    
    public func currentPhase(speed: Double = 0.3) -> Double {
        let now = CACurrentMediaTime()
        let delta = now - lastTime
        if delta > 0.005 {
            phase += min(delta, 0.1) * speed
            lastTime = now
        }
        return phase
    }
}

/// Fluid dynamic background canvas view.
public struct TTZipFluidBackgroundView: View {
    public let baseColor: Color
    public var speed: Double = 0.3
    
    @Environment(\.colorScheme) private var colorScheme
    
    public init(baseColor: Color = TTZipTheme.bambooGreen, speed: Double = 0.3) {
        self.baseColor = baseColor
        self.speed = speed
    }
    
    private var color1: Color { baseColor }
    private var color2: Color { baseColor.opacity(0.8) }
    private var color3: Color { baseColor.opacity(0.6) }
    
    public var body: some View {
        GeometryReader { geo in
            let fullW = geo.size.width
            let fullH = geo.size.height
            let scale: CGFloat = 4.0
            let w = max(fullW / scale, 100)
            let h = max(fullH / scale, 100)
            
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let currentPhase = TTZipGlobalFluidState.shared.currentPhase(speed: speed)
                
                Canvas { context, size in
                    let x1 = w / 2 + cos(currentPhase * 0.65) * (w * 0.3)
                    let y1 = h / 2 + sin(currentPhase * 1.05) * (h * 0.2)
                    let x2 = w / 2 + sin(currentPhase * 0.45) * (w * 0.4)
                    let y2 = h / 2 + cos(currentPhase * 0.95) * (h * 0.3)
                    let x3 = w / 2 + cos(currentPhase * 0.35) * (w * 0.25)
                    let y3 = h / 2 + sin(currentPhase * 0.55) * (h * 0.4)
                    
                    let radius = min(w, h) * 0.6
                    
                    context.blendMode = .normal
                    context.fill(Path(ellipseIn: CGRect(x: x1 - radius / 2, y: y1 - radius / 2, width: radius, height: radius)), with: .color(color1))
                    context.fill(Path(ellipseIn: CGRect(x: x2 - radius / 2, y: y2 - radius / 2, width: radius, height: radius)), with: .color(color2))
                    context.fill(Path(ellipseIn: CGRect(x: x3 - radius / 2, y: y3 - radius / 2, width: radius, height: radius)), with: .color(color3))
                }
                .frame(width: w, height: h)
                .blur(radius: 60 / scale)
                .scaleEffect(scale)
            }
            .frame(width: fullW, height: fullH, alignment: .center)
        }
        .opacity(colorScheme == .dark ? 0.35 : 0.18)
        .ignoresSafeArea()
    }
}
