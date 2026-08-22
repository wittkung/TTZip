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
    
    @State var player: AVPlayer? = nil
    @State var isPlaying = false
    @State var currentTime: Double = 0
    @State var duration: Double = 0
    @State var isEditingSlider = false
    @State var timeObserverToken: Any? = nil
    @State var rotationAngle: Double = 0
    @State var volume: Double = 1.0
    @State var isMuted: Bool = false
    
    @State var audioBitrate: String = "Analyzing..."
    @State var audioSampleRate: String = "44.1 kHz"
    @State var audioChannels: String = "Stereo"
    @State var fileSizeFormatted: String = ""
    
    public init(url: URL, fileName: String) {
        self.url = url
        self.fileName = fileName
    }
    
    var formatBadge: String {
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
}
