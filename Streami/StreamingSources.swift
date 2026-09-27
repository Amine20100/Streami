import Foundation
import Observation

// MARK: - Streaming Source Models

struct StreamingSource: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let baseURL: String
    let tvURL: String?
    let tvSeriesURL: String?
    let icon: String
    var isEnabled: Bool
    let supportsMovies: Bool
    let supportsTV: Bool
    let supportsAnime: Bool
    let requiresAPIKey: Bool
    let acceptsIMDB: Bool
    let priority: Int
    
    func movieEmbedURL(tmdbID: Int, imdbID: String?) -> URL? {
        let id = (acceptsIMDB && imdbID != nil) ? imdbID! : String(tmdbID)
        return URL(string: baseURL.replacingOccurrences(of: "{id}", with: id).replacingOccurrences(of: "{tmdb_id}", with: String(tmdbID)))
    }
    
    func tvEmbedURL(tmdbID: Int, imdbID: String?, season: Int, episode: Int) -> URL? {
        guard let tvURL = tvURL else { return nil }
        let id = (acceptsIMDB && imdbID != nil) ? imdbID! : String(tmdbID)
        var url = tvURL
            .replacingOccurrences(of: "{id}", with: id)
            .replacingOccurrences(of: "{tmdb_id}", with: String(tmdbID))
            .replacingOccurrences(of: "{season}", with: String(season))
            .replacingOccurrences(of: "{episode}", with: String(episode))
        return URL(string: url)
    }
    
    func tvSeriesEmbedURL(tmdbID: Int, imdbID: String?) -> URL? {
        guard let tvSeriesURL = tvSeriesURL else { return nil }
        let id = (acceptsIMDB && imdbID != nil) ? imdbID! : String(tmdbID)
        return URL(string: tvSeriesURL.replacingOccurrences(of: "{id}", with: id).replacingOccurrences(of: "{tmdb_id}", with: String(tmdbID)))
    }
}

// MARK: - Predefined Streaming Sources (Tested & Verified)

extension StreamingSource {
    static let allSources: [StreamingSource] = [
        // ===========================================
        // WORKING SOURCES (Tested 2024-09-27)
        // ===========================================
        
        // VidSrc Network - Best performing mirrors
        StreamingSource(
            id: "vidsrc.to",
            name: "VidSrc.to",
            baseURL: "https://vidsrc.to/embed/movie/{id}",
            tvURL: "https://vidsrc.to/embed/tv/{id}/{season}/{episode}",
            tvSeriesURL: "https://vidsrc.to/embed/tv/{id}",
            icon: "play.rectangle.fill",
            isEnabled: true,
            supportsMovies: true,
            supportsTV: true,
            supportsAnime: false,
            requiresAPIKey: false,
            acceptsIMDB: true,
            priority: 1
        ),
        StreamingSource(
            id: "vidsrc.sh",
            name: "VidSrc.sh",
            baseURL: "https://vidsrc.sh/embed/movie/{id}",
            tvURL: "https://vidsrc.sh/embed/tv/{id}/{season}/{episode}",
            tvSeriesURL: "https://vidsrc.sh/embed/tv/{id}",
            icon: "play.rectangle.fill",
            isEnabled: true,
            supportsMovies: true,
            supportsTV: true,
            supportsAnime: false,
            requiresAPIKey: false,
            acceptsIMDB: true,
            priority: 2
        ),
        StreamingSource(
            id: "vidsrc.io",
            name: "VidSrc.io",
            baseURL: "https://vidsrc.io/embed/movie/{id}",
            tvURL: "https://vidsrc.io/embed/tv/{id}/{season}/{episode}",
            tvSeriesURL: "https://vidsrc.io/embed/tv/{id}",
            icon: "play.rectangle.fill",
            isEnabled: true,
            supportsMovies: true,
            supportsTV: true,
            supportsAnime: false,
            requiresAPIKey: false,
            acceptsIMDB: true,
            priority: 3
        ),
        StreamingSource(
            id: "vidsrc.me",
            name: "VidSrc.me",
            baseURL: "https://vidsrc.me/embed/movie/{id}",
            tvURL: "https://vidsrc.me/embed/tv/{id}/{season}/{episode}",
            tvSeriesURL: "https://vidsrc.me/embed/tv/{id}",
            icon: "play.rectangle.fill",
            isEnabled: true,
            supportsMovies: true,
            supportsTV: true,
            supportsAnime: false,
            requiresAPIKey: false,
            acceptsIMDB: true,
            priority: 4
        ),
        StreamingSource(
            id: "vsembed.su",
            name: "VSEmbed.su",
            baseURL: "https://vsembed.su/embed/movie/{id}",
            tvURL: "https://vsembed.su/embed/tv/{id}/{season}/{episode}",
            tvSeriesURL: "https://vsembed.su/embed/tv/{id}",
            icon: "play.rectangle.fill",
            isEnabled: true,
            supportsMovies: true,
            supportsTV: true,
            supportsAnime: false,
            requiresAPIKey: false,
            acceptsIMDB: true,
            priority: 5
        ),
        
        // SuperEmbed (via embed-api.stream)
        StreamingSource(
            id: "superembed.stream",
            name: "SuperEmbed",
            baseURL: "https://watch.embed-api.stream/embed/movie/{id}",
            tvURL: "https://watch.embed-api.stream/embed/tv/{id}/{season}/{episode}",
            tvSeriesURL: nil,
            icon: "tv.fill",
            isEnabled: true,
            supportsMovies: true,
            supportsTV: true,
            supportsAnime: false,
            requiresAPIKey: false,
            acceptsIMDB: true,
            priority: 6
        ),
        
        // VidCore - High quality, ad-free
        StreamingSource(
            id: "vidcore.org",
            name: "VidCore",
            baseURL: "https://vidcore.org/embed/movie/{tmdb_id}",
            tvURL: "https://vidcore.org/embed/tv/{tmdb_id}/{season}/{episode}",
            tvSeriesURL: nil,
            icon: "film.fill",
            isEnabled: true,
            supportsMovies: true,
            supportsTV: true,
            supportsAnime: false,
            requiresAPIKey: false,
            acceptsIMDB: false,  // Only TMDB IDs
            priority: 7
        ),
        
        // NHD Embed - Supports anime, good quality
        StreamingSource(
            id: "nhdapi.com",
            name: "NHD Embed",
            baseURL: "https://nhdapi.com/movie/{id}",
            tvURL: "https://nhdapi.com/tv/{id}/{season}/{episode}",
            tvSeriesURL: nil,
            icon: "play.circle.fill",
            isEnabled: true,
            supportsMovies: true,
            supportsTV: true,
            supportsAnime: true,
            requiresAPIKey: false,
            acceptsIMDB: true,
            priority: 8
        ),
        
        // Embed API Stream (same as SuperEmbed but different domain)
        StreamingSource(
            id: "watch.embed-api.stream",
            name: "Embed API Stream",
            baseURL: "https://watch.embed-api.stream/embed/movie/{id}",
            tvURL: "https://watch.embed-api.stream/embed/tv/{id}/{season}/{episode}",
            tvSeriesURL: nil,
            icon: "antenna.radiowaves.left.and.right",
            isEnabled: true,
            supportsMovies: true,
            supportsTV: true,
            supportsAnime: false,
            requiresAPIKey: false,
            acceptsIMDB: true,
            priority: 9
        ),
        
        // VidSpark - Modern player with postMessage API
        StreamingSource(
            id: "vidspark.to",
            name: "VidSpark",
            baseURL: "https://vidspark.to/movie/{id}",
            tvURL: "https://vidspark.to/tv/{id}/{season}/{episode}",
            tvSeriesURL: "https://vidspark.to/tv/{id}",
            icon: "sparkles.tv.fill",
            isEnabled: true,
            supportsMovies: true,
            supportsTV: true,
            supportsAnime: false,
            requiresAPIKey: false,
            acceptsIMDB: true,
            priority: 10
        ),
        
        // ===========================================
        // DISABLED SOURCES (Issues found during testing)
        // ===========================================
        // Users can re-enable in Settings if they work in their region
        
        StreamingSource(
            id: "vidsrc.net",
            name: "VidSrc.net",
            baseURL: "https://vidsrc.net/embed/movie/{id}",
            tvURL: "https://vidsrc.net/embed/tv/{id}/{season}/{episode}",
            tvSeriesURL: "https://vidsrc.net/embed/tv/{id}",
            icon: "play.rectangle.fill",
            isEnabled: false,  // SSL Certificate issues
            supportsMovies: true,
            supportsTV: true,
            supportsAnime: false,
            requiresAPIKey: false,
            acceptsIMDB: true,
            priority: 99
        ),
        StreamingSource(
            id: "vidsrc.cc",
            name: "VidSrc.cc",
            baseURL: "https://vidsrc.cc/v3/embed/movie/{id}",
            tvURL: "https://vidsrc.cc/v3/embed/tv/{id}/{season}/{episode}",
            tvSeriesURL: "https://vidsrc.cc/v3/embed/tv/{id}",
            icon: "play.rectangle.fill",
            isEnabled: false,  // Timeout issues
            supportsMovies: true,
            supportsTV: true,
            supportsAnime: true,
            requiresAPIKey: false,
            acceptsIMDB: true,
            priority: 99
        ),
        StreamingSource(
            id: "embed.su",
            name: "Embed.su",
            baseURL: "https://embed.su/embed/movie/{id}",
            tvURL: "https://embed.su/embed/tv/{id}/{season}/{episode}",
            tvSeriesURL: "https://embed.su/embed/tv/{id}",
            icon: "play.rectangle.fill",
            isEnabled: false,  // DNS resolution failed
            supportsMovies: true,
            supportsTV: true,
            supportsAnime: false,
            requiresAPIKey: false,
            acceptsIMDB: true,
            priority: 99
        ),
        StreamingSource(
            id: "primesrc.me",
            name: "PrimeSrc (API)",
            baseURL: "https://primesrc.me/movie-tv/primesrc/movie/{id}",
            tvURL: "https://primesrc.me/movie-tv/primesrc/tv/{id}/{season}/{episode}",
            tvSeriesURL: nil,
            icon: "star.fill",
            isEnabled: false,  // Returns JSON API response, not embed player
            supportsMovies: true,
            supportsTV: true,
            supportsAnime: false,
            requiresAPIKey: false,
            acceptsIMDB: false,
            priority: 99
        ),
        StreamingSource(
            id: "ezvidapi.com",
            name: "EZVidAPI",
            baseURL: "https://ezvidapi.com/embed/movie/{id}",
            tvURL: "https://ezvidapi.com/embed/tv/{id}/{season}/{episode}",
            tvSeriesURL: nil,
            icon: "bolt.fill",
            isEnabled: false,  // HTTP 502 errors
            supportsMovies: true,
            supportsTV: true,
            supportsAnime: true,
            requiresAPIKey: false,
            acceptsIMDB: true,
            priority: 99
        ),
    ]
    
    static func sourcesForMovie() -> [StreamingSource] {
        allSources.filter { $0.supportsMovies && $0.isEnabled }.sorted { $0.priority < $1.priority }
    }
    
    static func sourcesForTV() -> [StreamingSource] {
        allSources.filter { $0.supportsTV && $0.isEnabled }.sorted { $0.priority < $1.priority }
    }
    
    static func sourcesForAnime() -> [StreamingSource] {
        allSources.filter { $0.supportsAnime && $0.isEnabled }.sorted { $0.priority < $1.priority }
    }
    
    /// Get all sources including disabled ones (for Settings)
    static var allSourcesIncludingDisabled: [StreamingSource] {
        allSources
    }
}

// MARK: - Watch Progress Model

struct WatchProgress: Codable, Hashable {
    let titleID: String
    let titleType: String // "movie" or "tv"
    let tmdbID: Int
    let imdbID: String?
    var currentTime: TimeInterval
    var duration: TimeInterval
    var season: Int?
    var episode: Int?
    var lastWatched: Date
    var sourceID: String
    
    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(currentTime / duration, 1.0)
    }
    
    var isCompleted: Bool {
        progress >= 0.9
    }
}

// MARK: - Streaming Source Manager

@Observable
@MainActor
final class StreamingSourceManager {
    static let shared = StreamingSourceManager()
    
    private let sourcesKey = "streami.streaming.sources"
    private let progressKey = "streami.watch.progress"
    
    var sources: [StreamingSource] = []
    var watchProgress: [String: WatchProgress] = [:]
    
    private init() {
        loadSources()
        loadProgress()
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
        default: return []
        }
    }
    
    func getEmbedURL(for sourceID: String, title: TMDBTitle, season: Int? = nil, episode: Int? = nil) -> URL? {
        guard let source = sources.first(where: { $0.id == sourceID }) else { return nil }
        let imdbID = title.imdbID
        
        if title.type == "movie" || (title.type == "tv" && season == nil) {
            return source.movieEmbedURL(tmdbID: title.id, imdbID: imdbID)
        } else if let season, let episode {
            return source.tvEmbedURL(tmdbID: title.id, imdbID: imdbID, season: season, episode: episode)
        } else {
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
    
    func updateProgress(
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
        watchProgress[titleID] = progress
        saveProgress()
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
}