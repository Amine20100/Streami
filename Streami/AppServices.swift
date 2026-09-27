import Foundation
import Observation

typealias TMDBClientFactory = (String) -> any TMDBServicing

#if STREAMI_LICENSED_PLAYBACK_ENABLED
// MARK: - Streaming Source Models

struct StreamingSource: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let baseURL: String
    let icon: String
    var isEnabled: Bool
    let supportsMovies: Bool
    let supportsTV: Bool
    let supportsAnime: Bool
    let requiresAPIKey: Bool
    let priority: Int

    func movieEmbedURL(tmdbID: Int, imdbID: String?) -> URL? {
        let id = imdbID ?? String(tmdbID)
        return URL(string: baseURL.replacingOccurrences(of: "{id}", with: id).replacingOccurrences(of: "{tmdb_id}", with: String(tmdbID)))
    }

    func tvEmbedURL(tmdbID: Int, imdbID: String?, season: Int, episode: Int) -> URL? {
        let id = imdbID ?? String(tmdbID)
        var url = baseURL
            .replacingOccurrences(of: "{id}", with: id)
            .replacingOccurrences(of: "{tmdb_id}", with: String(tmdbID))
            .replacingOccurrences(of: "{season}", with: String(season))
            .replacingOccurrences(of: "{episode}", with: String(episode))
        return URL(string: url)
    }

    func tvSeriesEmbedURL(tmdbID: Int, imdbID: String?) -> URL? {
        let id = imdbID ?? String(tmdbID)
        return URL(string: baseURL.replacingOccurrences(of: "{id}", with: id).replacingOccurrences(of: "{tmdb_id}", with: String(tmdbID)))
    }
}

extension StreamingSource {
    static let allSources: [StreamingSource] = [
        StreamingSource(id: "vidsrc.to", name: "VidSrc.to", baseURL: "https://vidsrc.to/embed/movie/{id}", icon: "play.rectangle.fill", isEnabled: true, supportsMovies: true, supportsTV: true, supportsAnime: false, requiresAPIKey: false, priority: 1),
        StreamingSource(id: "vidsrc.net", name: "VidSrc.net", baseURL: "https://vidsrc.net/embed/movie/{id}", icon: "play.rectangle.fill", isEnabled: true, supportsMovies: true, supportsTV: true, supportsAnime: false, requiresAPIKey: false, priority: 2),
        StreamingSource(id: "vidsrc.cc", name: "VidSrc.cc", baseURL: "https://vidsrc.cc/v3/embed/movie/{id}", icon: "play.rectangle.fill", isEnabled: true, supportsMovies: true, supportsTV: true, supportsAnime: true, requiresAPIKey: false, priority: 3),
        StreamingSource(id: "vidsrc.sh", name: "VidSrc.sh", baseURL: "https://vidsrc.sh/embed/movie/{id}", icon: "play.rectangle.fill", isEnabled: true, supportsMovies: true, supportsTV: true, supportsAnime: false, requiresAPIKey: false, priority: 4),
        StreamingSource(id: "vidsrc.io", name: "VidSrc.io", baseURL: "https://vidsrc.io/embed/movie/{id}", icon: "play.rectangle.fill", isEnabled: true, supportsMovies: true, supportsTV: true, supportsAnime: false, requiresAPIKey: false, priority: 5),
        StreamingSource(id: "vidsrc.me", name: "VidSrc.me", baseURL: "https://vidsrc.me/embed/movie/{id}", icon: "play.rectangle.fill", isEnabled: true, supportsMovies: true, supportsTV: true, supportsAnime: false, requiresAPIKey: false, priority: 6),
        StreamingSource(id: "vsembed.su", name: "VSEmbed.su", baseURL: "https://vsembed.su/embed/movie/{id}", icon: "play.rectangle.fill", isEnabled: true, supportsMovies: true, supportsTV: true, supportsAnime: false, requiresAPIKey: false, priority: 7),
        StreamingSource(id: "embed.su", name: "Embed.su", baseURL: "https://embed.su/embed/movie/{id}", icon: "play.rectangle.fill", isEnabled: true, supportsMovies: true, supportsTV: true, supportsAnime: false, requiresAPIKey: false, priority: 8),
        StreamingSource(id: "superembed.stream", name: "SuperEmbed", baseURL: "https://watch.embed-api.stream/embed/movie/{id}", icon: "tv.fill", isEnabled: true, supportsMovies: true, supportsTV: true, supportsAnime: false, requiresAPIKey: false, priority: 9),
        StreamingSource(id: "vidcore.org", name: "VidCore", baseURL: "https://vidcore.org/embed/movie/{tmdb_id}", icon: "film.fill", isEnabled: true, supportsMovies: true, supportsTV: true, supportsAnime: false, requiresAPIKey: false, priority: 10),
        StreamingSource(id: "nhdapi.com", name: "NHD Embed", baseURL: "https://nhdapi.com/movie/{id}", icon: "play.circle.fill", isEnabled: true, supportsMovies: true, supportsTV: true, supportsAnime: true, requiresAPIKey: false, priority: 11),
        StreamingSource(id: "primesrc.me", name: "PrimeSrc", baseURL: "https://primesrc.me/movie-tv/primesrc/movie/{id}", icon: "star.fill", isEnabled: true, supportsMovies: true, supportsTV: true, supportsAnime: false, requiresAPIKey: false, priority: 12),
        StreamingSource(id: "ezvidapi.com", name: "EZVidAPI", baseURL: "https://ezvidapi.com/embed/movie/{id}", icon: "bolt.fill", isEnabled: true, supportsMovies: true, supportsTV: true, supportsAnime: true, requiresAPIKey: false, priority: 13),
        StreamingSource(id: "watch.embed-api.stream", name: "Embed API Stream", baseURL: "https://watch.embed-api.stream/embed/movie/{id}", icon: "antenna.radiowaves.left.and.right", isEnabled: true, supportsMovies: true, supportsTV: true, supportsAnime: false, requiresAPIKey: false, priority: 14),
        StreamingSource(id: "vidspark.to", name: "VidSpark", baseURL: "https://vidspark.to/movie/{id}", icon: "sparkles.tv.fill", isEnabled: true, supportsMovies: true, supportsTV: true, supportsAnime: false, requiresAPIKey: false, priority: 15),
    ]

    static func sourcesForMovie() -> [StreamingSource] { allSources.filter { $0.supportsMovies && $0.isEnabled }.sorted { $0.priority < $1.priority } }
    static func sourcesForTV() -> [StreamingSource] { allSources.filter { $0.supportsTV && $0.isEnabled }.sorted { $0.priority < $1.priority } }
    static func sourcesForAnime() -> [StreamingSource] { allSources.filter { $0.supportsAnime && $0.isEnabled }.sorted { $0.priority < $1.priority } }
}

struct WatchProgress: Codable, Hashable {
    let titleID: String
    let titleType: String
    let tmdbID: Int
    let imdbID: String?
    var currentTime: TimeInterval
    var duration: TimeInterval
    var season: Int?
    var episode: Int?
    var lastWatched: Date
    var sourceID: String

    var progress: Double { guard duration > 0 else { return 0 }; return min(currentTime / duration, 1.0) }
    var isCompleted: Bool { progress >= 0.9 }
}

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
    
    var sourceHealthStatus: [String: SourceHealth] {
        sourceHealth
    }
    
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
    
    // MARK: - Debounced Progress Saving
    
    private var pendingProgress: [String: WatchProgress] = [:]
    private var progressSaveTimers: [String: Timer] = [:]
    private let progressSaveDelay: TimeInterval = 5.0 // Save every 5 seconds
    
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
        let titleID = season != nil && episode != nil ? "\(title.listID)-s\(season!)e\(episode!)" : title.listID
        let progress = WatchProgress(
            titleID: titleID,
            titleType: title.type,
            tmdbID: title.id,
            imdbID: nil,
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
        let key = season != nil && episode != nil ? "\(title.listID)-s\(season!)e\(episode!)" : title.listID
        return watchProgress[key]
    }

    func clearProgress(for title: TMDBTitle) {
        watchProgress.removeValue(forKey: title.listID)
        saveProgress()
    }

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
#endif

protocol CredentialStoring {
    func load() -> String
    func save(_ credential: String) throws
    func remove() throws
}

struct KeychainCredentialStore: CredentialStoring {
    func load() -> String { TokenVault.read() }
    func save(_ credential: String) throws { try TokenVault.save(credential) }
    func remove() throws { try TokenVault.delete() }
}

protocol WatchlistPersisting {
    func load() -> [TMDBTitle]
    func save(_ titles: [TMDBTitle])
}

enum PersonalizedCatalog {
    static func rank(_ candidates: [TMDBTitle], against savedTitles: [TMDBTitle]) -> [TMDBTitle] {
        let uniqueCandidates = Dictionary(candidates.map { ($0.listID, $0) }, uniquingKeysWith: { first, _ in first })
        let candidateRecords = uniqueCandidates.values.map { title in
            recommendationRecord(for: title)
        }
        let savedRecords = savedTitles.map { title in
            recommendationRecord(for: title)
        }
        let rankedIDs = RecommendationBridge.rankCandidates(
            candidateRecords,
            savedTitles: savedRecords,
            limit: 20
        )
        return rankedIDs.compactMap { uniqueCandidates[$0] }
    }

    private static func recommendationRecord(for title: TMDBTitle) -> [String: Any] {
        [
            "id": title.listID,
            "genres": (title.genreIDs ?? []).map { NSNumber(value: $0) },
            "voteAverage": title.voteAverage ?? 0,
            "voteCount": title.voteCount ?? 0,
            "popularity": title.popularity ?? 0
        ]
    }
}

struct WatchlistCollection: Codable, Hashable, Identifiable {
    let id: String
    var name: String
    var titleIDs: Set<String>
}

protocol WatchlistCollectionPersisting {
    func load() -> [WatchlistCollection]
    func save(_ collections: [WatchlistCollection])
    func loadSelectedID() -> String?
    func saveSelectedID(_ id: String)
}

struct UserDefaultsWatchlistCollectionPersistence: WatchlistCollectionPersisting {
    private let defaults: UserDefaults
    private let collectionsKey = "streami.watchlist.collections"
    private let selectedIDKey = "streami.watchlist.selectedCollection"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [WatchlistCollection] {
        guard let data = defaults.data(forKey: collectionsKey),
              let collections = try? JSONDecoder().decode([WatchlistCollection].self, from: data) else { return [] }
        return collections
    }

    func save(_ collections: [WatchlistCollection]) {
        guard let data = try? JSONEncoder().encode(collections) else { return }
        defaults.set(data, forKey: collectionsKey)
    }

    func loadSelectedID() -> String? { defaults.string(forKey: selectedIDKey) }
    func saveSelectedID(_ id: String) { defaults.set(id, forKey: selectedIDKey) }
}

struct UserDefaultsWatchlistStore: WatchlistPersisting {
    private let defaults: UserDefaults
    private let key = "streami.watchlist"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [TMDBTitle] {
        guard let data = defaults.data(forKey: key),
              let titles = try? JSONDecoder().decode([TMDBTitle].self, from: data) else { return [] }
        return titles
    }

    func save(_ titles: [TMDBTitle]) {
        guard let data = try? JSONEncoder().encode(titles) else { return }
        defaults.set(data, forKey: key)
    }
}

@Observable
@MainActor
final class TMDBSession {
    private let credentialStore: any CredentialStoring
    private let clientFactory: TMDBClientFactory
    private(set) var credential: String
    @ObservationIgnored private var currentClient: any TMDBServicing

    init(credentialStore: any CredentialStoring, clientFactory: @escaping TMDBClientFactory = { TMDBClient(token: $0) }) {
        self.credentialStore = credentialStore
        self.clientFactory = clientFactory
        let credential = credentialStore.load()
        self.credential = credential
        currentClient = clientFactory(credential)
    }

    var client: any TMDBServicing { currentClient }

    func updateCredential(_ credential: String) throws {
        try credentialStore.save(credential)
        self.credential = credentialStore.load()
        currentClient = clientFactory(self.credential)
    }

    func clearCredential() throws {
        try credentialStore.remove()
        credential = ""
        currentClient = clientFactory(credential)
    }
}

@Observable
@MainActor
final class AppPreferences {
    private let defaults: UserDefaults
    private let regionKey = "streami.region"
    var regionCode: String {
        didSet { defaults.set(regionCode, forKey: regionKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let localeRegion = Locale.current.region?.identifier.uppercased() ?? "US"
        let savedRegion = defaults.string(forKey: regionKey)
        regionCode = savedRegion ?? (localeRegion.count == 2 ? localeRegion : "US")
    }
}

@Observable
@MainActor
final class WatchlistStore {
    static let defaultCollectionID = "streami.collection.my-list"
    private let persistence: any WatchlistPersisting
    private let collectionPersistence: any WatchlistCollectionPersisting
    private(set) var titles: [TMDBTitle]
    private(set) var collections: [WatchlistCollection]
    private(set) var activeCollectionID: String {
        didSet { collectionPersistence.saveSelectedID(activeCollectionID) }
    }

    init(
        persistence: any WatchlistPersisting,
        collectionPersistence: any WatchlistCollectionPersisting = UserDefaultsWatchlistCollectionPersistence()
    ) {
        self.persistence = persistence
        self.collectionPersistence = collectionPersistence
        titles = persistence.load()
        let defaultCollection = WatchlistCollection(
            id: Self.defaultCollectionID,
            name: "My List",
            titleIDs: Set(titles.map(\.listID))
        )
        var storedCollections = collectionPersistence.load()
        if let defaultIndex = storedCollections.firstIndex(where: { $0.id == Self.defaultCollectionID }) {
            storedCollections[defaultIndex].titleIDs.formUnion(defaultCollection.titleIDs)
        } else {
            storedCollections.insert(defaultCollection, at: 0)
        }
        collections = storedCollections
        collectionPersistence.save(storedCollections)
        let selectedID = collectionPersistence.loadSelectedID()
        if let selectedID, storedCollections.contains(where: { $0.id == selectedID }) {
            activeCollectionID = selectedID
        } else {
            activeCollectionID = Self.defaultCollectionID
        }
    }

    var activeCollection: WatchlistCollection? { collections.first { $0.id == activeCollectionID } }
    var activeTitles: [TMDBTitle] {
        guard let collection = activeCollection else { return [] }
        return titles.filter { collection.titleIDs.contains($0.listID) }
    }

    func contains(_ title: TMDBTitle) -> Bool {
        titles.contains { $0.id == title.id && $0.type == title.type }
    }

    func contains(_ title: TMDBTitle, in collectionID: String) -> Bool {
        collections.first(where: { $0.id == collectionID })?.titleIDs.contains(title.listID) ?? false
    }

    func selectCollection(_ id: String) {
        guard collections.contains(where: { $0.id == id }) else { return }
        activeCollectionID = id
    }

    func createCollection(named name: String) -> Bool {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty,
              !collections.contains(where: { $0.name.caseInsensitiveCompare(cleanName) == .orderedSame }) else { return false }
        let collection = WatchlistCollection(id: UUID().uuidString, name: cleanName, titleIDs: [])
        collections.append(collection)
        collectionPersistence.save(collections)
        activeCollectionID = collection.id
        return true
    }

    func deleteCollection(_ id: String) {
        guard id != Self.defaultCollectionID else { return }
        collections.removeAll { $0.id == id }
        collectionPersistence.save(collections)
        if activeCollectionID == id { activeCollectionID = Self.defaultCollectionID }
    }

    func setMembership(_ title: TMDBTitle, in collectionID: String, isMember: Bool) {
        guard let index = collections.firstIndex(where: { $0.id == collectionID }) else { return }
        if isMember {
            if !contains(title) {
                titles.insert(title, at: 0)
                persistence.save(titles)
                if let defaultIndex = collections.firstIndex(where: { $0.id == Self.defaultCollectionID }) {
                    collections[defaultIndex].titleIDs.insert(title.listID)
                }
            }
            collections[index].titleIDs.insert(title.listID)
        } else if collectionID == Self.defaultCollectionID {
            titles.removeAll { $0.id == title.id && $0.type == title.type }
            persistence.save(titles)
            for collectionIndex in collections.indices {
                collections[collectionIndex].titleIDs.remove(title.listID)
            }
        } else {
            collections[index].titleIDs.remove(title.listID)
        }
        collectionPersistence.save(collections)
    }

    func toggle(_ title: TMDBTitle) {
        if contains(title) {
            titles.removeAll { $0.id == title.id && $0.type == title.type }
            for index in collections.indices {
                collections[index].titleIDs.remove(title.listID)
            }
        } else {
            titles.insert(title, at: 0)
            if let index = collections.firstIndex(where: { $0.id == Self.defaultCollectionID }) {
                collections[index].titleIDs.insert(title.listID)
            }
        }
        persistence.save(titles)
        collectionPersistence.save(collections)
    }
}

@Observable
@MainActor
final class DiscoverViewModel {
    private let session: TMDBSession
    private let preferences: AppPreferences
    private(set) var trending: [TMDBTitle] = []
    private(set) var trendingMovies: [TMDBTitle] = []
    private(set) var trendingShows: [TMDBTitle] = []
    private(set) var movies: [TMDBTitle] = []
    private(set) var topRatedMovies: [TMDBTitle] = []
    private(set) var nowPlayingMovies: [TMDBTitle] = []
    private(set) var upcomingMovies: [TMDBTitle] = []
    private(set) var shows: [TMDBTitle] = []
    private(set) var topRatedShows: [TMDBTitle] = []
    private(set) var onTheAirShows: [TMDBTitle] = []
    private(set) var airingTodayShows: [TMDBTitle] = []
    private(set) var movieCatalog: [TMDBTitle] = []
    private(set) var showCatalog: [TMDBTitle] = []
    private(set) var movieGenres: [TMDBGenre] = []
    private(set) var showGenres: [TMDBGenre] = []
    private(set) var movieProviders: [TMDBWatchProvider] = []
    private(set) var showProviders: [TMDBWatchProvider] = []
    private(set) var errorMessage: String?
    private(set) var catalogError: String?
    private(set) var filterError: String?
    private(set) var isLoading = false
    private(set) var isLoadingCatalog = false
    private(set) var isLoadingFilterOptions = false
    private var catalogRequestID = UUID()
    private var filterRequestID = UUID()

    init(session: TMDBSession, preferences: AppPreferences) {
        self.session = session
        self.preferences = preferences
    }

    func load() async {
        guard !session.credential.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            async let trendingRequest = session.client.trending()
            async let trendingMoviesRequest = session.client.trending(mediaType: "movie", timeWindow: "week")
            async let trendingShowsRequest = session.client.trending(mediaType: "tv", timeWindow: "week")
            async let movieRequest = session.client.popularMovies()
            async let topRatedMoviesRequest = session.client.topRatedMovies()
            async let nowPlayingRequest = session.client.nowPlayingMovies(region: preferences.regionCode)
            async let upcomingRequest = session.client.upcomingMovies(region: preferences.regionCode)
            async let showRequest = session.client.popularShows()
            async let topRatedShowsRequest = session.client.topRatedShows()
            async let onTheAirRequest = session.client.onTheAirShows()
            async let airingTodayRequest = session.client.airingTodayShows()
            
            (trending, trendingMovies, trendingShows, movies, topRatedMovies, nowPlayingMovies, upcomingMovies, shows, topRatedShows, onTheAirShows, airingTodayShows) = try await (
                trendingRequest, trendingMoviesRequest, trendingShowsRequest,
                movieRequest, topRatedMoviesRequest, nowPlayingRequest, upcomingRequest,
                showRequest, topRatedShowsRequest, onTheAirRequest, airingTodayRequest
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
        await loadFilterOptions(region: preferences.regionCode)
    }
    
    func loadMoreTrending(type: String? = nil, timeWindow: String = "week") async -> [TMDBTitle] {
        guard !session.credential.isEmpty else { return [] }
        do {
            return try await session.client.trending(mediaType: type, timeWindow: timeWindow)
        } catch {
            return []
        }
    }

    func loadFilterOptions(region: String) async {
        guard !session.credential.isEmpty else { return }
        let requestID = UUID()
        filterRequestID = requestID
        isLoadingFilterOptions = true
        filterError = nil
        defer {
            if filterRequestID == requestID { isLoadingFilterOptions = false }
        }
        async let movieGenreRequest = session.client.genres(for: "movie")
        async let showGenreRequest = session.client.genres(for: "tv")
        async let movieProviderRequest = session.client.providers(for: "movie", region: region)
        async let showProviderRequest = session.client.providers(for: "tv", region: region)
        do {
            let options = try await (
                movieGenreRequest,
                showGenreRequest,
                movieProviderRequest,
                showProviderRequest
            )
            guard filterRequestID == requestID, !Task.isCancelled else { return }
            (movieGenres, showGenres, movieProviders, showProviders) = options
        } catch is CancellationError {
            return
        } catch {
            guard filterRequestID == requestID else { return }
            filterError = error.localizedDescription
        }
    }

    func loadCatalog(type: String, filters: TMDBDiscoveryFilters) async {
        guard !session.credential.isEmpty else { return }
        let requestID = UUID()
        catalogRequestID = requestID
        isLoadingCatalog = true
        catalogError = nil
        defer {
            if catalogRequestID == requestID { isLoadingCatalog = false }
        }
        do {
            let results = try await session.client.discover(type: type, filters: filters, region: preferences.regionCode)
            guard catalogRequestID == requestID, !Task.isCancelled else { return }
            if type == "movie" {
                movieCatalog = results
            } else {
                showCatalog = results
            }
        } catch is CancellationError {
            return
        } catch {
            guard catalogRequestID == requestID else { return }
            catalogError = error.localizedDescription
        }
    }

    func personalizedTitles(from savedTitles: [TMDBTitle]) -> [TMDBTitle] {
        let candidates = Dictionary(
            (trending + movies + shows).map { ($0.listID, $0) },
            uniquingKeysWith: { first, _ in first }
        ).values
        return PersonalizedCatalog.rank(Array(candidates), against: savedTitles)
    }

    func reset() {
        trending = []
        movies = []
        shows = []
        movieCatalog = []
        showCatalog = []
        errorMessage = nil
        catalogError = nil
        filterError = nil
        catalogRequestID = UUID()
        filterRequestID = UUID()
        isLoading = false
        isLoadingCatalog = false
        isLoadingFilterOptions = false
    }
}

@Observable
@MainActor
final class SearchViewModel {
    private let session: TMDBSession
    private(set) var results: [TMDBTitle] = []
    private(set) var errorMessage: String?
    private(set) var isSearching = false
    private var requestID = UUID()

    init(session: TMDBSession) {
        self.session = session
    }

    func search(_ query: String) async {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else {
            reset()
            return
        }

        let currentRequestID = UUID()
        requestID = currentRequestID
        isSearching = true
        defer {
            if requestID == currentRequestID { isSearching = false }
        }

        do {
            let newResults = try await session.client.search(cleanQuery)
            guard requestID == currentRequestID, !Task.isCancelled else { return }
            results = newResults
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            guard requestID == currentRequestID else { return }
            errorMessage = error.localizedDescription
        }
    }

    func reset() {
        requestID = UUID()
        results = []
        errorMessage = nil
        isSearching = false
    }
}

@Observable
@MainActor
final class DetailViewModel {
    let title: TMDBTitle
    private let session: TMDBSession
    private let preferences: AppPreferences
    private let watchlist: WatchlistStore
    private(set) var providerRegion: TMDBProviderRegion?
    private(set) var isLoadingProviders = true
    private(set) var providerError: String?
    private(set) var recommendations: [TMDBTitle] = []
    private(set) var similar: [TMDBTitle] = []
    private(set) var recommendationsError: String?
    private(set) var isLoadingRecommendations = true
    private(set) var details: TMDBTitleDetails?
    private(set) var isLoadingDetails = true
    private(set) var detailsError: String?
    private(set) var isLoadingTrailer = false
    private(set) var imdbID: String?
    private(set) var videos: [TMDBVideo] = []
    private(set) var images: TMDBImages?
    private(set) var reviews: TMDBReviewsPage?
    private(set) var keywords: TMDBKeywords?
    private(set) var releaseDates: TMDBReleaseDates?
    private(set) var contentRatings: TMDBContentRatings?
    private(set) var translations: TMDBTranslations?
    private(set) var alternativeTitles: TMDBAlternativeTitles?

    init(title: TMDBTitle, session: TMDBSession, preferences: AppPreferences, watchlist: WatchlistStore) {
        self.title = title
        self.session = session
        self.preferences = preferences
        self.watchlist = watchlist
    }

    var regionCode: String { preferences.regionCode }
    var isSaved: Bool { watchlist.contains(title) }
    
    var displayRuntime: String? {
        guard let runtime = details?.displayRuntime else { return nil }
        let hours = runtime / 60
        let minutes = runtime % 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
    
    var certification: String? {
        let region = regionCode.uppercased()
        return details?.releaseDates?.results?.first(where: { $0.iso3166_1 == region })?.releaseDates?.first(where: { !$0.certification.isEmpty })?.certification
            ?? details?.releaseDates?.results?.first(where: { $0.iso3166_1 == "US" })?.releaseDates?.first(where: { !$0.certification.isEmpty })?.certification
    }
    
    var directors: [TMDBCastMember] {
        details?.crew.filter { $0.job == "Director" || $0.job == "Creator" } ?? []
    }
    
    var creators: [TMDBCastMember] {
        details?.crew.filter { $0.job == "Creator" } ?? []
    }

    func loadSupportingData() async {
        isLoadingProviders = true
        isLoadingRecommendations = true
        isLoadingDetails = true
        providerError = nil
        recommendationsError = nil
        detailsError = nil
        
        async let providerRequest = session.client.watchProviders(for: title, region: regionCode)
        async let recommendationRequest = session.client.recommendations(for: title)
        async let similarRequest = session.client.similar(for: title)
        async let detailsRequest = session.client.details(for: title)
        async let imdbRequest = session.client.fetchExternalIDs(for: title)
        async let videosRequest = session.client.videos(for: title)
        async let imagesRequest = session.client.images(for: title)
        async let reviewsRequest = session.client.reviews(for: title)
        async let keywordsRequest = session.client.keywords(for: title)
        async let releaseDatesRequest = session.client.releaseDates(for: title)
        async let contentRatingsRequest = session.client.contentRatings(for: title)
        async let translationsRequest = session.client.translations(for: title)
        async let alternativeTitlesRequest = session.client.alternativeTitles(for: title)

        do {
            providerRegion = try await providerRequest
        } catch is CancellationError {
            isLoadingProviders = false
            return
        } catch {
            providerRegion = nil
            providerError = error.localizedDescription
        }
        isLoadingProviders = false

        do {
            recommendations = try await recommendationRequest
        } catch is CancellationError {
            isLoadingRecommendations = false
            return
        } catch {
            recommendations = []
            recommendationsError = error.localizedDescription
        }
        
        do {
            similar = try await similarRequest
        } catch {
            similar = []
        }
        isLoadingRecommendations = false

        do {
            details = try await detailsRequest
        } catch is CancellationError {
            isLoadingDetails = false
            return
        } catch {
            details = nil
            detailsError = error.localizedDescription
        }
        isLoadingDetails = false

        do {
            imdbID = try await imdbRequest
        } catch {
            imdbID = nil
        }
        
        do {
            videos = try await videosRequest
            images = try await imagesRequest
            reviews = try await reviewsRequest
            keywords = try await keywordsRequest
            releaseDates = try await releaseDatesRequest
            contentRatings = try await contentRatingsRequest
            translations = try await translationsRequest
            alternativeTitles = try await alternativeTitlesRequest
        } catch {
            // Optional data, ignore errors
        }
    }

    func trailerURL() async -> URL? {
        isLoadingTrailer = true
        defer { isLoadingTrailer = false }
        return try? await session.client.trailerURL(for: title)
    }
}

@Observable
@MainActor
final class SettingsViewModel {
    private let session: TMDBSession
    private let preferences: AppPreferences
    private let discover: DiscoverViewModel
    private let search: SearchViewModel
    private(set) var errorMessage: String?

    init(session: TMDBSession, preferences: AppPreferences, discover: DiscoverViewModel, search: SearchViewModel) {
        self.session = session
        self.preferences = preferences
        self.discover = discover
        self.search = search
    }

    var credential: String { session.credential }
    var regionCode: String { preferences.regionCode }

    func save(credential: String, region: String) async -> Bool {
        let cleanCredential = credential.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanRegion = region.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanCredential.isEmpty else {
            errorMessage = "Enter a TMDB API key or Read Access Token."
            return false
        }
        guard cleanRegion.range(of: "^[A-Z]{2}$", options: .regularExpression) != nil else {
            errorMessage = "Enter a two-letter country code, such as US or GB."
            return false
        }
        do {
            try session.updateCredential(cleanCredential)
            preferences.regionCode = cleanRegion
            errorMessage = nil
            await discover.load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func clearCredential() {
        do {
            try session.clearCredential()
            discover.reset()
            search.reset()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@Observable
@MainActor
final class AppServices {
    let session: TMDBSession
    let preferences: AppPreferences
    let watchlist: WatchlistStore
    let discover: DiscoverViewModel
    let search: SearchViewModel
    let settings: SettingsViewModel

    init(
        credentialStore: any CredentialStoring = KeychainCredentialStore(),
        watchlistPersistence: any WatchlistPersisting = UserDefaultsWatchlistStore(),
        watchlistCollectionPersistence: any WatchlistCollectionPersisting = UserDefaultsWatchlistCollectionPersistence(),
        clientFactory: @escaping TMDBClientFactory = { TMDBClient(token: $0) },
        defaults: UserDefaults = .standard
    ) {
        let session = TMDBSession(credentialStore: credentialStore, clientFactory: clientFactory)
        let preferences = AppPreferences(defaults: defaults)
        let watchlist = WatchlistStore(persistence: watchlistPersistence, collectionPersistence: watchlistCollectionPersistence)
        let discover = DiscoverViewModel(session: session, preferences: preferences)
        let search = SearchViewModel(session: session)
        self.session = session
        self.preferences = preferences
        self.watchlist = watchlist
        self.discover = discover
        self.search = search
        settings = SettingsViewModel(session: session, preferences: preferences, discover: discover, search: search)
    }
}