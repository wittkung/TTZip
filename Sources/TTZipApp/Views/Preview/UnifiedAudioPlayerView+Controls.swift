// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import AVFoundation
import TTZipCore

extension UnifiedAudioPlayerView {
    func audioMetaTag(title: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
    
    func setupPlayer() {
        cleanUpPlayer()
        let newPlayer = AVPlayer(url: url)
        self.player = newPlayer
        
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserverToken = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            Task { @MainActor in
                if !self.isEditingSlider {
                    self.currentTime = time.seconds
                }
                if let item = newPlayer.currentItem, item.duration.seconds.isFinite {
                    self.duration = item.duration.seconds
                }
            }
        }
        
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let s = attrs[.size] as? Int64 {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useAll]
            formatter.countStyle = .file
            self.fileSizeFormatted = formatter.string(fromByteCount: s)
        }
        
        let asset = AVURLAsset(url: url)
        Task.detached(priority: .userInitiated) {
            var br = "256 kbps"
            var sr = "44.1 kHz"
            var ch = "Stereo"
            
            if let tracks = try? await asset.load(.tracks) {
                for track in tracks {
                    if track.mediaType == .audio {
                        if let rate = try? await track.load(.estimatedDataRate), rate > 0 {
                            br = String(format: "%.0f kbps", Double(rate) / 1000.0)
                        }
                        if let descs = try? await track.load(.formatDescriptions),
                           let desc = descs.first,
                           let basic = CMAudioFormatDescriptionGetStreamBasicDescription(desc) {
                            let freq = basic.pointee.mSampleRate
                            if freq > 0 {
                                sr = String(format: "%.1f kHz", freq / 1000.0)
                            }
                            let channels = basic.pointee.mChannelsPerFrame
                            if channels == 1 {
                                ch = "Mono"
                            } else if channels == 2 {
                                ch = "Stereo"
                            } else if channels > 2 {
                                ch = "\(channels) Channels Surround"
                            }
                        }
                    }
                }
            }
            
            await MainActor.run {
                self.audioBitrate = br
                self.audioSampleRate = sr
                self.audioChannels = ch
            }
        }
        
        self.isPlaying = false
        startRotation()
    }
    
    func cleanUpPlayer() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        player?.pause()
        player?.rate = 0
        player?.replaceCurrentItem(with: nil)
        player = nil
        isPlaying = false
    }
    
    func togglePlayPause() {
        guard let p = player else { return }
        if isPlaying {
            p.pause()
            isPlaying = false
        } else {
            p.play()
            isPlaying = true
        }
    }
    
    func seekBy(_ seconds: Double) {
        let newTime = min(max(currentTime + seconds, 0), max(duration, 0.01))
        currentTime = newTime
        let targetTime = CMTime(seconds: newTime, preferredTimescale: 600)
        player?.seek(to: targetTime)
    }
    
    func startRotation() {
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
    }
    
    func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "00:00" }
        let secs = Int(seconds)
        let m = secs / 60
        let s = secs % 60
        return String(format: "%02d:%02d", m, s)
    }
}
