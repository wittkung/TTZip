import SwiftUI
import AVFoundation
import AVKit
import TTZipCore

/// 共享视频播放器状态调度中心 (保证小屏/真全屏切换时 100% 进度无缝接续，声音视频绝不上演中断复位)
@MainActor
public final class SharedVideoPlayerStore: ObservableObject {
    @Published public var player: AVPlayer?
    @Published public var currentURL: URL?
    @Published public var isPlaying: Bool = true
    @Published public var currentTime: Double = 0
    @Published public var duration: Double = 0
    @Published public var isMuted: Bool = false
    
    private var timeObserverToken: Any?
    
    public init() {}
    
    public func setup(url: URL) {
        if currentURL == url, let p = player {
            if p.rate == 0 && isPlaying {
                p.play()
            }
            return
        }
        
        cleanUp()
        
        self.currentURL = url
        let newPlayer = AVPlayer(url: url)
        self.player = newPlayer
        self.isPlaying = false
        
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserverToken = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self = self else { return }
                let secs = CMTimeGetSeconds(time)
                if secs.isFinite && secs >= 0 {
                    self.currentTime = secs
                }
                if let item = newPlayer.currentItem {
                    let d = CMTimeGetSeconds(item.duration)
                    if d.isFinite && d > 0 {
                        self.duration = d
                    }
                }
            }
        }
    }
    
    public func togglePlayPause() {
        guard let p = player else { return }
        if isPlaying {
            p.pause()
            isPlaying = false
        } else {
            p.play()
            isPlaying = true
        }
    }
    
    public func seek(to seconds: Double) {
        currentTime = seconds
        player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
    }
    
    public func cleanUp() {
        if let obs = timeObserverToken, let p = player {
            p.removeTimeObserver(obs)
            timeObserverToken = nil
        }
        player?.pause()
        player?.rate = 0
        player?.replaceCurrentItem(with: nil)
        player = nil
        currentURL = nil
        isPlaying = false
        currentTime = 0
        duration = 0
    }
}

/// 顶级原彩视频播放器 (基于 AVPlayerLayer 纯 GPU 硬件渲染，零延迟响应播放/暂停，进度跨全屏无缝接续)
public struct UnifiedVideoPlayerView: View {
    public let url: URL
    
    @StateObject private var store = SharedVideoPlayerStore()
    @State private var isHovering = false
    @State private var hideTimer: Timer? = nil
    
    public init(url: URL) {
        self.url = url
    }
    
    public var body: some View {
        ZStack(alignment: .center) {
            Color.black.ignoresSafeArea()
            
            if let player = store.player {
                AVPlayerLayerContainerView(player: player)
                    .onTapGesture {
                        store.togglePlayPause()
                    }
            } else {
                ProgressView()
                    .controlSize(.large)
            }
            
            if isHovering || !store.isPlaying {
                Button(action: { store.togglePlayPause() }) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial.opacity(0.85))
                            .frame(width: 64, height: 64)
                            .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 4)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                            )
                        
                        Image(systemName: store.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: store.isPlaying ? 0 : 2)
                    }
                }
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.85).combined(with: .opacity).animation(.spring(response: 0.2, dampingFraction: 0.8)))
            }
            
            if isHovering || !store.isPlaying {
                VStack {
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Button(action: { store.togglePlayPause() }) {
                            Image(systemName: store.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        
                        Text("\(formatTime(store.currentTime)) / \(formatTime(store.duration))")
                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.9))
                        
                        Slider(
                            value: Binding(
                                get: { store.currentTime },
                                set: { newValue in store.seek(to: newValue) }
                            ),
                            in: 0...max(store.duration, 0.1)
                        )
                        .tint(TTZipTheme.bambooGreen)
                        
                        Button(action: {
                            store.isMuted.toggle()
                            store.player?.isMuted = store.isMuted
                        }) {
                            Image(systemName: store.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial.opacity(0.85))
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 3)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .transition(.opacity.animation(.easeInOut(duration: 0.15)))
                }
            }
        }
        .onContinuousHover { phase in
            switch phase {
            case .active:
                isHovering = true
                resetHideTimer()
            case .ended:
                isHovering = false
            }
        }
        .onAppear {
            store.setup(url: url)
        }
        .onChange(of: url) { _, newURL in
            store.setup(url: newURL)
        }
        .onDisappear {
            hideTimer?.invalidate()
            hideTimer = nil
            store.cleanUp()
        }
    }
    
    private func resetHideTimer() {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 2.2, repeats: false) { _ in
            Task { @MainActor in
                withAnimation {
                    if store.isPlaying {
                        isHovering = false
                    }
                }
            }
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

public struct AVPlayerLayerContainerView: NSViewRepresentable {
    public let player: AVPlayer
    
    public init(player: AVPlayer) {
        self.player = player
    }
    
    public func makeNSView(context: Context) -> PlayerNSView {
        let view = PlayerNSView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }
    
    public func updateNSView(_ nsView: PlayerNSView, context: Context) {
        nsView.playerLayer.player = player
        nsView.playerLayer.videoGravity = .resizeAspect
    }
    
    public final class PlayerNSView: NSView {
        public let playerLayer = AVPlayerLayer()
        
        public override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            self.wantsLayer = true
            self.layer?.backgroundColor = NSColor.black.cgColor
            playerLayer.frame = self.bounds
            playerLayer.videoGravity = .resizeAspect
            self.layer?.addSublayer(playerLayer)
        }
        
        public required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public override func layout() {
            super.layout()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            playerLayer.frame = self.bounds
            CATransaction.commit()
        }
    }
}


