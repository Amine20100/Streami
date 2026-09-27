import SwiftUI
import WebKit

// MARK: - Streaming Player View

struct StreamingPlayerView: View {
    @Environment(AppServices.self) private var services
    @Environment(StreamingSourceManager.self) private var sourceManager
    let title: TMDBTitle
    let source: StreamingSource
    let season: Int?
    let episode: Int?
    @State private var webView: WKWebView?
    @State private var isLoading = true
    @State private var error: String?
    @State private var showControls = true
    @State private var progress: Double = 0
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var hasLoadedSavedProgress = false
    @State private var showNextEpisode = false
    @Environment(\.dismiss) private var dismiss
    
    private var embedURL: URL? {
        if title.type == "movie" || (title.type == "tv" && season == nil) {
            return source.movieEmbedURL(tmdbID: title.id, imdbID: title.imdbID)
        } else if let season, let episode {
            return source.tvEmbedURL(tmdbID: title.id, imdbID: title.imdbID, season: season, episode: episode)
        } else {
            return source.tvSeriesEmbedURL(tmdbID: title.id, imdbID: title.imdbID)
        }
    }
    
    private var savedProgress: WatchProgress? {
        sourceManager.getPendingProgress(for: title, season: season, episode: episode)
    }
    
    private var shouldResume: Bool {
        guard let saved = savedProgress else { return false }
        return saved.progress > 0.02 && saved.progress < 0.95 && !hasLoadedSavedProgress
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let url = embedURL {
                WebView(
                    url: url,
                    isLoading: $isLoading,
                    error: $error,
                    onProgress: { progress in
                        self.progress = progress
                    },
                    onMessage: { message in
                        handlePlayerMessage(message)
                    },
                    savedProgress: savedProgress,
                    shouldResume: shouldResume
                )
                .ignoresSafeArea()
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)
                    Text("Unable to create embed URL")
                        .font(.headline)
                    Text("This source may not support this content type")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text("Loading \(source.name)...")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black.opacity(0.8))
            }
            
            if let error {
                VStack(spacing: 16) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 48))
                        .foregroundStyle(.red)
                    Text("Failed to Load")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Button("Try Another Source") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.white, in: Capsule())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black.opacity(0.9))
            }
            
            // Resume prompt overlay
            if shouldResume && isLoading == false {
                ResumePromptView(
                    progress: savedProgress!,
                    onResume: {
                        hasLoadedSavedProgress = true
                        seekToSavedPosition()
                    },
                    onRestart: {
                        hasLoadedSavedProgress = true
                    }
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { 
                    commitProgress()
                    dismiss() 
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.black.opacity(0.4), in: Circle())
                }
            }
            ToolbarItem(placement: .principal) {
                VStack(alignment: .center, spacing: 2) {
                    Text(title.displayTitle)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if let season, let episode {
                        Text("S\(season) E\(episode)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    if duration > 0 {
                        Text("\(formatTime(currentTime)) / \(formatTime(duration))")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    if title.type == "tv" && season != nil && episode != nil {
                        Button {
                            playNextEpisode()
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(.black.opacity(0.4), in: Circle())
                        }
                    }
                    
                    Button {
                        togglePiP()
                    } label: {
                        Image(systemName: "pip")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.black.opacity(0.4), in: Circle())
                    }
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onDisappear {
            commitProgress()
        }
    }
    
    private func handlePlayerMessage(_ message: Any) {
        guard let dict = message as? [String: Any],
              let type = dict["type"] as? String else { return }
        
        switch type {
        case "timeupdate":
            if let currentTime = dict["currentTime"] as? TimeInterval,
               let duration = dict["duration"] as? TimeInterval {
                self.currentTime = currentTime
                self.duration = duration
                
                // Debounced progress save
                sourceManager.updateProgressDebounced(
                    title: title,
                    currentTime: currentTime,
                    duration: duration,
                    season: season,
                    episode: episode,
                    sourceID: source.id
                )
            }
        case "ended":
            // Mark as completed
            sourceManager.updateProgressDebounced(
                title: title,
                currentTime: dict["duration"] as? TimeInterval ?? 0,
                duration: dict["duration"] as? TimeInterval ?? 0,
                season: season,
                episode: episode,
                sourceID: source.id
            )
            // Show next episode prompt for TV shows
            if title.type == "tv", season != nil, episode != nil {
                showNextEpisode = true
            }
        case "ready":
            // Player is ready, inject seek if needed
            if shouldResume {
                seekToSavedPosition()
            }
        default:
            break
        }
    }
    
    private func seekToSavedPosition() {
        guard let saved = savedProgress else { return }
        let script = """
            (function() {
                function seekVideo() {
                    var videos = document.querySelectorAll('video');
                    videos.forEach(function(video) {
                        video.currentTime = \(saved.currentTime);
                    });
                    var iframes = document.querySelectorAll('iframe');
                    iframes.forEach(function(iframe) {
                        try {
                            var iframeDoc = iframe.contentDocument || iframe.contentWindow.document;
                            var videos = iframeDoc.querySelectorAll('video');
                            videos.forEach(function(video) {
                                video.currentTime = \(saved.currentTime);
                            });
                        } catch (e) {}
                    });
                }
                seekVideo();
                setTimeout(seekVideo, 1000);
            })();
        """
        webView?.evaluateJavaScript(script) { _, _ in }
        hasLoadedSavedProgress = true
    }
    
    private func commitProgress() {
        if duration > 0 {
            sourceManager.updateProgressDebounced(
                title: title,
                currentTime: currentTime,
                duration: duration,
                season: season,
                episode: episode,
                sourceID: source.id
            )
        }
        sourceManager.commitAllPendingProgress()
    }
    
    private func playNextEpisode() {
        guard let season = season, let episode = episode else { return }
        dismiss()
        // Post notification for parent to handle next episode
        NotificationCenter.default.post(
            name: .playNextEpisode,
            object: nil,
            userInfo: [
                "title": title,
                "season": season,
                "nextEpisode": episode + 1,
                "sourceID": source.id
            ]
        )
    }
    
    private func togglePiP() {
        let script = """
            (function() {
                var videos = document.querySelectorAll('video');
                videos.forEach(function(video) {
                    if (video.webkitSupportsPresentationMode && typeof video.webkitSetPresentationMode === 'function') {
                        video.webkitSetPresentationMode(video.webkitPresentationMode === 'picture-in-picture' ? 'inline' : 'picture-in-picture');
                    } else if (document.pictureInPictureEnabled) {
                        if (document.pictureInPictureElement === video) {
                            document.exitPictureInPicture();
                        } else {
                            video.requestPictureInPicture().catch(console.error);
                        }
                    }
                });
            })();
        """
        webView?.evaluateJavaScript(script) { _, _ in }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) % 3600 / 60
        let seconds = Int(time) % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, seconds) }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Resume Prompt View

struct ResumePromptView: View {
    let progress: WatchProgress
    let onResume: () -> Void
    let onRestart: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            
            Text("Resume from \(formatTime(progress.currentTime))?")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            
            Text("You watched \(Int(progress.progress * 100))%")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
            
            HStack(spacing: 16) {
                Button("Restart") {
                    onRestart()
                }
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(.white.opacity(0.2), in: Capsule())
                .foregroundStyle(.white)
                
                Button("Resume") {
                    onResume()
                }
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(.orange, in: Capsule())
                .foregroundStyle(.white)
            }
        }
        .padding(32)
        .background(.black.opacity(0.95), in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 40)
        .shadow(radius: 20)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) % 3600 / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}

// MARK: - WebView Wrapper

struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var error: String?
    let onProgress: (Double) -> Void
    let onMessage: (Any) -> Void
    let savedProgress: WatchProgress?
    let shouldResume: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsPictureInPictureMediaPlayback = true
        
        // Add message handler for postMessage from iframe
        configuration.userContentController.add(context.coordinator, name: "player")
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.backgroundColor = .black
        webView.isOpaque = false
        
        context.coordinator.webView = webView
        context.coordinator.onProgress = onProgress
        context.coordinator.onMessage = onMessage
        context.coordinator.isLoading = $isLoading
        context.coordinator.error = $error
        context.coordinator.savedProgress = savedProgress
        context.coordinator.shouldResume = shouldResume
        
        let request = URLRequest(url: url)
        webView.load(request)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?
        var onProgress: ((Double) -> Void)?
        var onMessage: ((Any) -> Void)?
        var isLoading: Binding<Bool>?
        var error: Binding<String?>?
        var progressObservation: NSKeyValueObservation?
        var savedProgress: WatchProgress?
        var shouldResume: Bool
        var hasInjectedScripts = false
        
        init() {
            self.shouldResume = false
            super.init()
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading?.wrappedValue = true
            error?.wrappedValue = nil
            
            progressObservation = webView.observe(\.estimatedProgress, options: .new) { [weak self] webView, _ in
                self?.onProgress?(webView.estimatedProgress)
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading?.wrappedValue = false
            progressObservation?.invalidate()
            
            // Inject scripts after page load
            if !hasInjectedScripts {
                hasInjectedScripts = true
                injectTrackingScripts()
                
                // Notify player is ready
                if shouldResume {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.onMessage?(["type": "ready"])
                    }
                }
            }
        }
        
        private func injectTrackingScripts() {
            // Enhanced tracking script with better cross-origin handling
            let script = """
                (function() {
                    var trackedVideos = new Set();
                    var lastReportTime = 0;
                    var reportInterval = 2000; // Report every 2 seconds
                    
                    // Listen for postMessage from iframe
                    window.addEventListener('message', function(event) {
                        if (event.data && event.data.type) {
                            window.webkit.messageHandlers.player.postMessage(event.data);
                        }
                    });
                    
                    function trackVideo(video) {
                        if (trackedVideos.has(video)) return;
                        trackedVideos.add(video);
                        
                        video.addEventListener('timeupdate', function() {
                            var now = Date.now();
                            if (now - lastReportTime >= reportInterval) {
                                lastReportTime = now;
                                window.webkit.messageHandlers.player.postMessage({
                                    type: 'timeupdate',
                                    currentTime: video.currentTime,
                                    duration: video.duration || 0
                                });
                            }
                        });
                        
                        video.addEventListener('ended', function() {
                            window.webkit.messageHandlers.player.postMessage({
                                type: 'ended',
                                duration: video.duration || 0
                            });
                        });
                        
                        video.addEventListener('play', function() {
                            window.webkit.messageHandlers.player.postMessage({
                                type: 'play',
                                currentTime: video.currentTime
                            });
                        });
                        
                        video.addEventListener('pause', function() {
                            window.webkit.messageHandlers.player.postMessage({
                                type: 'pause',
                                currentTime: video.currentTime
                            });
                        });
                        
                        // Notify ready
                        if (video.readyState >= 2) {
                            window.webkit.messageHandlers.player.postMessage({
                                type: 'ready',
                                currentTime: video.currentTime,
                                duration: video.duration || 0
                            });
                        } else {
                            video.addEventListener('loadeddata', function() {
                                window.webkit.messageHandlers.player.postMessage({
                                    type: 'ready',
                                    currentTime: video.currentTime,
                                    duration: video.duration || 0
                                });
                            }, { once: true });
                        }
                    }
                    
                    function scanForVideos() {
                        var videos = document.querySelectorAll('video');
                        videos.forEach(trackVideo);
                        
                        // Also check iframes
                        var iframes = document.querySelectorAll('iframe');
                        iframes.forEach(function(iframe) {
                            try {
                                var iframeDoc = iframe.contentDocument || iframe.contentWindow.document;
                                var videos = iframeDoc.querySelectorAll('video');
                                videos.forEach(trackVideo);
                            } catch (e) {
                                // Cross-origin iframe, can't access directly
                                // Try postMessage to iframe
                                iframe.contentWindow.postMessage({ type: 'streami:track' }, '*');
                            }
                        });
                    }
                    
                    // Initial scan
                    scanForVideos();
                    
                    // Periodic scan for dynamically added videos
                    setInterval(scanForVideos, 3000);
                    
                    // Listen for messages from iframes
                    window.addEventListener('message', function(event) {
                        if (event.data && event.data.type && event.data.type.startsWith('streami:')) {
                            window.webkit.messageHandlers.player.postMessage(event.data);
                        }
                    });
                })();
            """
            webView.evaluateJavaScript(script) { _, _ in }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading?.wrappedValue = false
            self.error?.wrappedValue = error.localizedDescription
            progressObservation?.invalidate()
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isLoading?.wrappedValue = false
            self.error?.wrappedValue = error.localizedDescription
            progressObservation?.invalidate()
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            onMessage?(message.body)
        }
        
        // Allow popups for external links
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let playStreamingSource = Notification.Name("playStreamingSource")
    static let playNextEpisode = Notification.Name("playNextEpisode")
}

// MARK: - Preview

#Preview {
    StreamingPlayerView(
        title: TMDBTitle(id: 533535, title: "Deadpool & Wolverine", overview: nil, posterPath: nil, backdropPath: nil, voteAverage: 8.5, releaseDate: "2024-07-25", firstAirDate: nil, mediaType: "movie", imdbID: "tt6263850"),
        source: StreamingSource.allSources.first!,
        season: nil,
        episode: nil
    )
    .environment(AppServices())
    .environment(StreamingSourceManager.shared)
}