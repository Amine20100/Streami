import Foundation
import Observation

typealias TMDBClientFactory = (String) -> any TMDBServicing



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
            async let trendingRequest = session.client.trending(mediaType: nil, timeWindow: "week")
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

struct DetailViewModel {
    let title: TMDBTitle
    let session: TMDBSession
    let preferences: AppPreferences
    let watchlist: WatchlistStore
    var providerRegion: TMDBProviderRegion?
    var isLoadingProviders = true
    var providerError: String?
    var recommendations: [TMDBTitle] = []
    var similar: [TMDBTitle] = []
    var recommendationsError: String?
    var isLoadingRecommendations = true
    var details: TMDBTitleDetails?
    var isLoadingDetails = true
    var detailsError: String?
    var isLoadingTrailer = false
    var imdbID: String?
    var videos: [TMDBVideo] = []
    var images: TMDBImages?
    var reviews: TMDBReviewsPage?
    var keywords: TMDBKeywords?
    var releaseDates: TMDBReleaseDates?
    var contentRatings: TMDBContentRatings?
    var translations: TMDBTranslations?
    var alternativeTitles: TMDBAlternativeTitles?

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
        return details?.releaseDates?.results?.first(where: { $0.iso3166_1 == region })?.releaseDates?.first(where: { !($0.certification?.isEmpty ?? true) })?.certification
            ?? details?.releaseDates?.results?.first(where: { $0.iso3166_1 == "US" })?.releaseDates?.first(where: { !($0.certification?.isEmpty ?? true) })?.certification
    }
    
    var directors: [TMDBCastMember] {
        details?.crew.filter { $0.job == "Director" || $0.job == "Creator" } ?? []
    }
    
    var creators: [TMDBCastMember] {
        details?.crew.filter { $0.job == "Creator" } ?? []
    }

    mutating func loadSupportingData() async {
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
            imdbID = try await imdbRequest?.imdb_id
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

    mutating func trailerURL() async -> URL? {
        isLoadingTrailer = true
        defer { isLoadingTrailer = false }
        return try? await session.client.trailerURL(for: title)
    }
    
    mutating func toggleSaved() {
        watchlist.toggle(title)
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
