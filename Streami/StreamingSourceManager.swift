import Foundation
import Observation

@Observable
@MainActor
final class StreamingSourceManager {
    static let shared = StreamingSourceManager()
    
    private let sourcesKey = "streami.streaming.sources"
    private let progressKey = "streami.watch.progress"
    private let autoSelectKey = "streami.streaming.autoSelect"
    private let lastHealthCheckKey = "streami.streaming.lastHealthCheck"
    
    var sources: [StreamingSource] = []
    var watchProgress: [String: WatchProgress] = [:]
    var autoSelectBestSource: Bool = true
    private var sourceHealth: [String: SourceHealth] = [:]
    
    private init() {
        loadSources()
        loadProgress()
        loadAutoSelectSetting()
        Task { await performHealthCheckIfNeeded() }
    }
    
    // MARK: - Auto Server Selection
    
    struct SourceHealth: Codable {
        let sourceID: String
        var isHealthy: Bool
        var responseTimeMs: Double
        var lastChecked: Date
        var consecutiveFailures: Int
    }
    
    var sourceHealthStatus: [String: SourceHealth] {
        sourceHealth
    }
    
    func loadAutoSelectSetting() {
        autoSelectBestSource = UserDefaults.standard.object(forKey: autoSelectKey) as? Bool ?? true
    }
    
    func setAutoSelect(_ enabled: Bool) {
        autoSelectBestSource = enabled
        UserDefaults.standard.set(enabled, forKey: autoSelectKey)
    }
    
    func getBestSource(for type: String) -> StreamingSource? {
        guard autoSelectBestSource else {
            return enabledSources(for: type).first
        }
        
        let enabled = enabledSources(for: type)
        guard !enabled.isEmpty else { return nil }
        
        // Sort by health (healthy first), then by priority, then by response time
        return enabled.sorted { lhs, rhs in
            let lhsHealth = sourceHealth[lhs.id]
            let rhsHealth = sourceHealth[rhs.id]
            
            let lhsHealthy = lhsHealth?.isHealthy ?? true
            let rhsHealthy = rhsHealth?.isHealthy ?? true
            
            if lhsHealthy != rhsHealthy {
                return lhsHealthy && !rhsHealthy
            }
            
            if lhs.priority != rhs.priority {
                return lhs.priority < rhs.priority
            }
            
            let lhsTime = lhsHealth?.responseTimeMs ?? Double.infinity
            let rhsTime = rhsHealth?.responseTimeMs ?? Double.infinity
            return lhsTime < rhsTime
        }.first
    }
    
    func getBestSourceURL(for title: TMDBTitle, season: Int? = nil, episode: Int? = nil) -> (URL, StreamingSource)? {
        let type = title.type == "movie" ? "movie" : "tv"
        guard let source = getBestSource(for: type) else { return nil }
        guard let url = getEmbedURL(for: source.id, title: title, season: season, episode: episode) else { return nil }
        return (url, source)
    }
    
    func recordSourceResult(sourceID: String, success: Bool, responseTime: Double) {
        var health = sourceHealth[sourceID] ?? SourceHealth(
            sourceID: sourceID,
            isHealthy: true,
            responseTimeMs: responseTime,
            lastChecked: Date(),
            consecutiveFailures: 0
        )
        
        health.lastChecked = Date()
        health.responseTimeMs = responseTime
        
        if success {
            health.consecutiveFailures = 0
            health.isHealthy = true
        } else {
            health.consecutiveFailures += 1
            if health.consecutiveFailures >= 3 {
                health.isHealthy = false
            }
        }
        
        sourceHealth[sourceID] = health
        saveHealth()
    }
    
    private func loadHealth() {
        if let data = UserDefaults.standard.data(forKey: "streami.streaming.health"),
           let decoded = try? JSONDecoder().decode([SourceHealth].self, from: data) {
            sourceHealth = Dictionary(uniqueKeysWithValues: decoded.map { ($0.sourceID, $0) })
        }
    }
    
    private func saveHealth() {
        if let data = try? JSONEncoder().encode(Array(sourceHealth.values)) {
            UserDefaults.standard.set(data, forKey: "streami.streaming.health")
        }
    }
    
    func performHealthCheckIfNeeded() async {
        let lastCheck = UserDefaults.standard.object(forKey: lastHealthCheckKey) as? Date ?? .distantPast
        let interval: TimeInterval = 6 * 60 * 60 // 6 hours
        
        guard Date().timeIntervalSince(lastCheck) > interval else { return }
        await performHealthCheck()
    }
    
    func performHealthCheck() async {
        UserDefaults.standard.set(Date(), forKey: lastHealthCheckKey)
        loadHealth()
        
        let testTitle = TMDBTitle(id: 533535, title: "Test", overview: nil, posterPath: nil, backdropPath: nil, voteAverage: 0, releaseDate: nil, firstAirDate: nil, mediaType: "movie")
        
        for source in sources where source.isEnabled {
            guard let url = source.movieEmbedURL(tmdbID: testTitle.id, imdbID: nil) else { continue }
            
            let start = Date()
            var success = false
            
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "HEAD"
                request.timeoutInterval = 10
                let (_, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, (200..<400).contains(http.statusCode) {
                    success = true
                }
            } catch {
                success = false
            }
            
            let responseTime = Date().timeIntervalSince(start) * 1000
            recordSourceResult(sourceID: source.id, success: success, responseTime: responseTime)
        }
    }
    
    // MARK: - Sources Management
    
    func loadSources() {
        if let data = UserDefaults.standard.data(forKey: sourcesKey),
           let decoded = try? JSONDecoder().decode([StreamingSource].self, from: data) {
            sources = decoded
        } else {
            sources = StreamingSource.allSources
            saveSources()
        }
    }
    
    func saveSources() {
        if let data = try? JSONEncoder().encode(sources) {
            UserDefaults.standard.set(data, forKey: sourcesKey)
        }
    }
    
    func toggleSource(_ sourceID: String) {
        if let index = sources.firstIndex(where: { $0.id == sourceID }) {
            sources[index].isEnabled.toggle()
            saveSources()
        }
    }
    
    func updateSource(_ source: StreamingSource) {
        if let index = sources.firstIndex(where: { $0.id == source.id }) {
            sources[index] = source
            saveSources()
        }
    }
    
    func enabledSources(for type: String) -> [StreamingSource] {
        switch type {
        case "movie": return sources.filter { $0.supportsMovies && $0.isEnabled }.sorted { $0.priority < $1.priority }
        case "tv": return sources.filter { $0.supportsTV && $0.isEnabled }.sorted { $0.priority < $1.priority }
        case "anime": return sources.filter { $0.supportsAnime && $0.isEnabled }.sorted { $0.priority < $1.priority }
        default: return [] }
    }
    
    func getEmbedURL(for sourceID: String, title: TMDBTitle, season: Int? = nil, episode: Int? = nil) -> URL? {
        guard let source = sources.first(where: { $0.id == sourceID }) else { return nil }
        let imdbID = title.imdbID
        
        if title.type == "movie" {
            return source.movieEmbedURL(tmdbID: title.id, imdbID: imdbID)
        } else if let season, let episode {
            return source.tvEmbedURL(tmdbID: title.id, imdbID: imdbID, season: season, episode: episode)
        } else {
            // TV without a selected episode: never fall back to a movie URL.
            return source.tvSeriesEmbedURL(tmdbID: title.id, imdbID: imdbID)
        }
    }
    
    // MARK: - Watch Progress Management
    
    func loadProgress() {
        if let data = UserDefaults.standard.data(forKey: progressKey),
           let decoded = try? JSONDecoder().decode([WatchProgress].self, from: data) {
            watchProgress = Dictionary(uniqueKeysWithValues: decoded.map { ($0.titleID, $0) })
        }
    }
    
    func saveProgress() {
        let array = Array(watchProgress.values)
        if let data = try? JSONEncoder().encode(array) {
            UserDefaults.standard.set(data, forKey: progressKey)
        }
    }
    
    func updateProgressDebounced(
        title: TMDBTitle,
        currentTime: TimeInterval,
        duration: TimeInterval,
        season: Int? = nil,
        episode: Int? = nil,
        sourceID: String
    ) {
        let titleID = (season != nil && episode != nil) ? "\(title.listID)-s\(season!)e\(episode!)" : title.listID
        let progress = WatchProgress(
            titleID: titleID,
            titleType: title.type,
            tmdbID: title.id,
            imdbID: title.imdbID,
            currentTime: currentTime,
            duration: duration,
            season: season,
            episode: episode,
            lastWatched: Date(),
            sourceID: sourceID
        )
        
        // Store pending progress
        pendingProgress[titleID] = progress
        
        // Cancel existing timer
        progressSaveTimers[titleID]?.invalidate()
        
        // Schedule debounced save
        let timer = Timer.scheduledTimer(withTimeInterval: progressSaveDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.commitPendingProgress(for: titleID)
            }
        }
        progressSaveTimers[titleID] = timer
    }
    
    func commitPendingProgress(for titleID: String) {
        if let progress = pendingProgress.removeValue(forKey: titleID) {
            watchProgress[titleID] = progress
            saveProgress()
        }
        progressSaveTimers[titleID]?.invalidate()
        progressSaveTimers.removeValue(forKey: titleID)
    }
    
    func commitAllPendingProgress() {
        for (titleID, progress) in pendingProgress {
            watchProgress[titleID] = progress
        }
        pendingProgress.removeAll()
        for timer in progressSaveTimers.values {
            timer.invalidate()
        }
        progressSaveTimers.removeAll()
        saveProgress()
    }
    
    func getPendingProgress(for title: TMDBTitle, season: Int? = nil, episode: Int? = nil) -> WatchProgress? {
        let titleID = (season != nil && episode != nil) ? "\(title.listID)-s\(season!)e\(episode!)" : title.listID
        return pendingProgress[titleID] ?? watchProgress[titleID]
    }
    
    func getProgress(for title: TMDBTitle, season: Int? = nil, episode: Int? = nil) -> WatchProgress? {
        let key = (season != nil && episode != nil) ? "\(title.listID)-s\(season!)e\(episode!)" : title.listID
        return watchProgress[key]
    }
    
    func clearProgress(for title: TMDBTitle) {
        watchProgress.removeValue(forKey: title.listID)
        saveProgress()
    }
    
    func clearAllProgress() {
        watchProgress.removeAll()
        saveProgress()
    }
    
    // MARK: - Continue Watching
    
    var continueWatching: [WatchProgress] {
        watchProgress.values
            .filter { !$0.isCompleted }
            .sorted { $0.lastWatched > $1.lastWatched }
    }
    
    var recentlyCompleted: [WatchProgress] {
        watchProgress.values
            .filter { $0.isCompleted }
            .sorted { $0.lastWatched > $1.lastWatched }
            .prefix(10)
            .map { $0 }
    }
    
    // MARK: - Debounced Progress Saving
    
    private var pendingProgress: [String: WatchProgress] = [:]
    private var progressSaveTimers: [String: Timer] = [:]
    private let progressSaveDelay: TimeInterval = 5.0 // Save every 5 seconds
}