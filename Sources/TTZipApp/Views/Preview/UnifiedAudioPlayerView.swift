// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import AVFoundation
import TTZipCore

public struct UnifiedAudioPlayerView: View {
    public let url: URL
    public let fileName: String
    
    @State private var player: AVPlayer? = nil
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isEditingSlider = false
    @State private var timeObserverToken: Any? = nil
    @State private var rotationAngle: Double = 0
    @State private var volume: Double = 1.0
    @State private var isMuted: Bool = false
    
    @State private var audioBitrate: String = "Analyzing..."
    @State private var audioSampleRate: String = "44.1 kHz"
    @State private var audioChannels: String = "Stereo"
    @State private var fileSizeFormatted: String = ""
    
    public init(url: URL, fileName: String) {
        self.url = url
        self.fileName = fileName
    }
    
    private var formatBadge: String {
        url.pathExtension.uppercased()
    }
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    isPlaying ? TTZipTheme.bambooGreen.opacity(0.35) : TTZipTheme.kintsugiGold.opacity(0.15),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 100
                            )
                        )
                        .frame(width: 190, height: 190)
                        .blur(radius: isPlaying ? 12 : 6)
                    
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(white: 0.05), Color(white: 0.18), Color(white: 0.03)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 146, height: 146)
                            .shadow(color: Color.black.opacity(0.45), radius: 10, x: 0, y: 6)
                        
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1.5)
                            .frame(width: 124, height: 124)
                        Circle()
                            .stroke(Color.white.opacity(0.06), lineWidth: 1.5)
                            .frame(width: 102, height: 102)
                        Circle()
                            .stroke(TTZipTheme.kintsugiGold.opacity(0.3), lineWidth: 1)
                            .frame(width: 80, height: 80)
                        
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [TTZipTheme.bambooGreen, TTZipTheme.kintsugiGold],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 44, height: 44)
                                .shadow(color: TTZipTheme.bambooGreen.opacity(0.4), radius: 6)
                            
                            Image(systemName: isPlaying ? "wave.3.forward" : "music.note")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .rotationEffect(.degrees(rotationAngle))
                }
                .padding(.top, 12)
                
                VStack(spacing: 6) {
                    Text(fileName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                    
                    HStack(spacing: 6) {
                        Text(formatBadge)
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(TTZipTheme.bambooGreen)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(TTZipTheme.bambooGreen.opacity(0.14))
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(TTZipTheme.bambooGreen.opacity(0.3), lineWidth: 0.8))
                        
                        if !audioBitrate.contains("Analyzing") {
                            Text(audioBitrate)
                                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(TTZipTheme.kintsugiGold)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2.5)
                                .background(TTZipTheme.kintsugiGold.opacity(0.14))
                                .clipShape(Capsule())
                                .overlay(Capsule().strokeBorder(TTZipTheme.kintsugiGold.opacity(0.3), lineWidth: 0.8))
                        }
                    }
                }
                
                AudioWaveformVisualizerView(isPlaying: isPlaying, barCount: 28)
                    .padding(.horizontal, 18)
                
                VStack(spacing: 6) {
                    Slider(value: $currentTime, in: 0...max(duration, 0.01)) { editing in
                        isEditingSlider = editing
                        if !editing {
                            let targetTime = CMTime(seconds: currentTime, preferredTimescale: 600)
                            player?.seek(to: targetTime)
                        }
                    }
                    .tint(TTZipTheme.bambooGreen)
                    
                    HStack {
                        Text(formatTime(currentTime))
                            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(TTZipTheme.bambooGreen)
                        Spacer()
                        Text(formatTime(duration))
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                
                VStack(spacing: 14) {
                    HStack(spacing: 32) {
                        Button {
                            seekBy(-15)
                        } label: {
                            Image(systemName: "gobackward.15")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                        .help("Rewind 15 seconds")
                        
                        Button {
                            togglePlayPause()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [TTZipTheme.bambooGreen, Color(red: 0.15, green: 0.65, blue: 0.45)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 52, height: 52)
                                    .shadow(color: TTZipTheme.bambooGreen.opacity(0.4), radius: isPlaying ? 10 : 4)
                                
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(.white)
                                    .offset(x: isPlaying ? 0 : 2)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            seekBy(15)
                        } label: {
                            Image(systemName: "goforward.15")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                        .help("Forward 15 seconds")
                    }
                    
                    HStack(spacing: 10) {
                        Button {
                            isMuted.toggle()
                            player?.isMuted = isMuted
                        } label: {
                            Image(systemName: isMuted ? "speaker.slash.fill" : (volume > 0.5 ? "speaker.wave.3.fill" : "speaker.wave.1.fill"))
                                .font(.system(size: 11))
                                .foregroundStyle(isMuted ? TTZipTheme.cinnabarRed : Color.secondary)
                        }
                        .buttonStyle(.plain)
                        
                        Slider(value: $volume, in: 0...1) { _ in
                            player?.volume = Float(volume)
                            if volume > 0 && isMuted {
                                isMuted = false
                                player?.isMuted = false
                            }
                        }
                        .tint(TTZipTheme.bambooGreen.opacity(0.7))
                        .frame(width: 100)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.025))
                    .clipShape(Capsule())
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Label("Audio Specs", systemImage: "waveform.circle.fill")
                        .font(.system(size: 11.5, weight: .bold, design: .serif))
                        .foregroundStyle(TTZipTheme.kintsugiGold)
                    
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                        GridRow {
                            audioMetaTag(title: "Format", value: formatBadge)
                            audioMetaTag(title: "Sample Rate", value: audioSampleRate)
                        }
                        GridRow {
                            audioMetaTag(title: "Bitrate", value: audioBitrate)
                            audioMetaTag(title: "Channels", value: audioChannels)
                        }
                        GridRow {
                            audioMetaTag(title: "File Size", value: fileSizeFormatted.isEmpty ? "--" : fileSizeFormatted)
                            audioMetaTag(title: "Duration", value: formatTime(duration))
                        }
                    }
                }
                .padding(14)
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
                )
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            setupPlayer()
        }
        .onChange(of: url) { _, _ in
            setupPlayer()
        }
        .onDisappear {
            cleanUpPlayer()
        }
    }
    
    private func audioMetaTag(title: String, value: String) -> some View {
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
    
    private func setupPlayer() {
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
    
    private func cleanUpPlayer() {
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
    
    private func togglePlayPause() {
        guard let p = player else { return }
        if isPlaying {
            p.pause()
            isPlaying = false
        } else {
            p.play()
            isPlaying = true
        }
    }
    
    private func seekBy(_ seconds: Double) {
        let newTime = min(max(currentTime + seconds, 0), max(duration, 0.01))
        currentTime = newTime
        let targetTime = CMTime(seconds: newTime, preferredTimescale: 600)
        player?.seek(to: targetTime)
    }
    
    private func startRotation() {
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "00:00" }
        let secs = Int(seconds)
        let m = secs / 60
        let s = secs % 60
        return String(format: "%02d:%02d", m, s)
    }
}
