// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore

public struct AudioWaveformVisualizerView: View {
    public let isPlaying: Bool
    public var barCount: Int = 24
    
    @State private var phase: Double = 0
    @State private var timerToken: Timer? = nil
    
    public init(isPlaying: Bool, barCount: Int = 24) {
        self.isPlaying = isPlaying
        self.barCount = barCount
    }
    
    public var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                let normalized = Double(index) / Double(barCount)
                let sineValue = sin(normalized * Double.pi * 3 + phase)
                let cosValue = cos(normalized * Double.pi * 2 - phase * 1.5)
                let heightMultiplier = isPlaying ? max(0.15, abs(sineValue * 0.6 + cosValue * 0.4)) : 0.15
                
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                TTZipTheme.bambooGreen,
                                TTZipTheme.kintsugiGold.opacity(0.85)
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 3.5, height: max(6, 32 * heightMultiplier))
                    .shadow(color: isPlaying ? TTZipTheme.bambooGreen.opacity(0.3) : Color.clear, radius: 4)
                    .animation(.easeInOut(duration: 0.12), value: heightMultiplier)
            }
        }
        .frame(height: 36)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
        )
        .onAppear {
            if isPlaying {
                startTimer()
            }
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: isPlaying) { _, newValue in
            if newValue {
                startTimer()
            } else {
                stopTimer()
            }
        }
    }
    
    private func startTimer() {
        stopTimer()
        timerToken = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
            if isPlaying {
                Task { @MainActor in
                    withAnimation(.linear(duration: 0.08)) {
                        self.phase += 0.25
                    }
                }
            }
        }
    }
    
    private func stopTimer() {
        timerToken?.invalidate()
        timerToken = nil
    }
}
