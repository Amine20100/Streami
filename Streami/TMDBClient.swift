import Foundation
import Security

// MARK: - Core Models

struct TMDBTitle: Codable, Hashable, Identifiable {
    let id: Int
    var title: String?
    var name: String?
    var overview: String?
    var posterPath: String?
    var backdropPath: String?
    var voteAverage: Double?
    var voteCount: Int?
    var popularity: Double?
    var genreIDs: [Int]?
    var releaseDate: String?
    var firstAirDate: String?
    var mediaType: String?
    var imdbID: String?
    var adult: Bool?
    var originalLanguage: String?
    var originalTitle: String?
    var originalName: String?
    var video: Bool?
    
    var displayTitle: String { title ?? name ?? "Untitled" }
    var type: String { mediaType ?? (name == nil ? "movie" : "tv") }
    var listID: String { "\(type)-\(id)" }
    var year: String { String((releaseDate ?? firstAirDate ?? "").prefix(4)) }
    var posterURL: URL? { imageURL(path: posterPath, size: "w500") }
    var backdropURL: URL? { imageURL(path: backdropPath, size: "w1280") }
    var logoURL: URL? { imageURL(path: posterPath, size: "w154") }
    
    enum CodingKeys: String, CodingKey {
        case id, title, name, overview, adult
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case popularity
        case genreIDs = "genre_ids"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case mediaType = "media_type"
        case imdbID = "imdb_id"
        case originalLanguage = "original_language"
        case originalTitle = "original_title"
        case originalName = "original_name"
        case video
    }
    
    private func imageURL(path: String?, size: String) -> URL? {
        guard let path else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/\(size)\(path)")
    }
}

struct TMDBGenre: Decodable, Hashable, Identifiable {
    let id: Int
    let name: String
}

struct TMDBDiscoveryFilters: Hashable {
    var genreID: Int?
    var year: Int?
    var sortBy: String
    var providerID: Int?
    var certification: String?
    var keywordIDs: [Int]?
    var includeAdult: Bool?
    var language: String?
    var page: Int?
    
    static let defaults = TMDBDiscoveryFilters(genreID: nil, year: nil, sortBy: "popularity.desc", providerID: nil)
}

struct TMDBWatchProvider: Decodable, Hashable, Identifiable {
    let providerID: Int
    let providerName: String
    let logoPath: String?
    
    var id: Int { providerID }
    var logoURL: URL? {
        guard let logoPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w92\(logoPath)")
    }
    
    enum CodingKeys: String, CodingKey {
        case providerID = "provider_id"
        case providerName = "provider_name"
        case logoPath = "logo_path"
    }
}

struct TMDBCastRole: Decodable {
    let character: String?
}

struct TMDBCastMember: Decodable, Identifiable {
    let id: Int
    let name: String
    let character: String?
    let roles: [TMDBCastRole]?
    let profilePath: String?
    let creditID: String?
    let order: Int?
    let job: String?
    let department: String?
    
    var creditDescription: String {
        character ?? roles?.first?.character ?? job ?? department ?? "Cast"
    }
    
    var profileURL: URL? {
        guard let profilePath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w185\(profilePath)")
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, character, roles
        case profilePath = "profile_path"
        case creditID = "credit_id"
        case order, job, department
    }
}

struct TMDBCredits: Decodable {
    let cast: [TMDBCastMember]?
    let crew: [TMDBCastMember]?
}

struct TMDBTitleDetails: Decodable {
    let genres: [TMDBGenre]?
    let runtime: Int?
    let episodeRunTime: [Int]?
    let credits: TMDBCredits?
    let aggregateCredits: TMDBCredits?
    let externalIDs: TMDBExternalIDs?
    let videos: TMDBVideoPage?
    let images: TMDBImages?
    let recommendations: TMDBPage<TMDBTitle>?
    let similar: TMDBPage<TMDBTitle>?
    let reviews: TMDBReviewsPage?
    let keywords: TMDBKeywords?
    let releaseDates: TMDBReleaseDates?
    let contentRatings: TMDBContentRatings?
    let translations: TMDBTranslations?
    let alternativeTitles: TMDBAlternativeTitles?
    let status: String?
    let tagline: String?
    let homepage: String?
    let productionCompanies: [TMDBCompany]?
    let productionCountries: [TMDBCountry]?
    let spokenLanguages: [TMDBSpokenLanguage]?
    let budget: Int?
    let revenue: Int?
    let originCountry: [String]?
    let originalLanguage: String?
    let inProduction: Bool?
    let lastAirDate: String?
    let nextEpisodeToAir: TMDBEpisode?
    let numberOfSeasons: Int?
    let numberOfEpisodes: Int?
    let seasons: [TMDBSeason]?
    let episodeGroups: [TMDBEpisodeGroup]?
    let type: String?
    var cast: [TMDBCastMember] { Array((credits?.cast ?? aggregateCredits?.cast ?? []).prefix(12)) }
    var crew: [TMDBCastMember] { (credits?.crew ?? aggregateCredits?.crew ?? []).filter { $0.job == "Director" || $0.job == "Creator" || $0.job == "Executive Producer" } }
    var displayRuntime: Int? { runtime ?? episodeRunTime?.first }
    
    enum CodingKeys: String, CodingKey {
        case genres, runtime, status, tagline, homepage
        case episodeRunTime = "episode_run_time"
        case credits, aggregateCredits
        case externalIDs = "external_ids"
        case videos, images, recommendations, similar, reviews, keywords
        case releaseDates = "release_dates"
        case contentRatings = "content_ratings"
        case translations, alternativeTitles = "alternative_titles"
        case productionCompanies = "production_companies"
        case productionCountries = "production_countries"
        case spokenLanguages = "spoken_languages"
        case budget, revenue, originCountry = "origin_country"
        case originalLanguage = "original_language"
        case inProduction = "in_production"
        case lastAirDate = "last_air_date"
        case nextEpisodeToAir = "next_episode_to_air"
        case numberOfSeasons = "number_of_seasons"
        case numberOfEpisodes = "number_of_episodes"
        case seasons, episodeGroups = "episode_groups"
        case type
    }
}

// MARK: - Additional Detail Models

struct TMDBExternalIDs: Decodable {
    let imdb_id: String?
    let facebook_id: String?
    let instagram_id: String?
    let twitter_id: String?
    let tiktok_id: String?
    let wikipedia_id: String?
}

struct TMDBVideoPage: Decodable {
    let results: [TMDBVideo]
}

struct TMDBVideo: Decodable, Identifiable {
    let id: String
    let key: String
    let site: String
    let type: String
    let name: String
    let official: Bool?
    let publishedAt: String?
    let size: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, key, site, type, name, official
        case publishedAt = "published_at"
        case size
    }
}

struct TMDBImages: Decodable {
    let backdrops: [TMDBImage]?
    let posters: [TMDBImage]?
    let logos: [TMDBImage]?
}

struct TMDBImage: Decodable, Identifiable {
    let filePath: String
    var id: String { filePath }
    let aspectRatio: Double?
    let height: Int?
    let width: Int?
    let voteAverage: Double?
    let voteCount: Int?
    let iso639_1: String?
    
    var url: URL? { URL(string: "https://image.tmdb.org/t/p/original\(filePath)") }
    var thumbnailURL: URL? { URL(string: "https://image.tmdb.org/t/p/w300\(filePath)") }
    
    enum CodingKeys: String, CodingKey {
        case filePath = "file_path"
        case aspectRatio = "aspect_ratio"
        case height, width
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case iso639_1
    }
}

struct TMDBReviewsPage: Decodable {
    let page: Int
    let results: [TMDBReview]
    let totalPages: Int
    let totalResults: Int
    
    enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

struct TMDBReview: Decodable, Identifiable {
    let id: String
    let author: String
    let authorDetails: TMDBAuthorDetails?
    let content: String
    let createdAt: String
    let updatedAt: String
    let url: String
    
    enum CodingKeys: String, CodingKey {
        case id, author, content, url
        case authorDetails = "author_details"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct TMDBAuthorDetails: Decodable {
    let name: String?
    let username: String?
    let avatarPath: String?
    let rating: Double?
    
    enum CodingKeys: String, CodingKey {
        case name, username, rating
        case avatarPath = "avatar_path"
    }
}

struct TMDBKeywords: Decodable {
    let keywords: [TMDBKeyword]?
}

struct TMDBKeyword: Decodable, Identifiable {
    let id: Int
    let name: String
}

struct TMDBReleaseDates: Decodable {
    let results: [TMDBReleaseDateResult]?
}

struct TMDBReleaseDateResult: Decodable {
    let iso3166_1: String
    let releaseDates: [TMDBReleaseDate]?
    
    enum CodingKeys: String, CodingKey {
        case iso3166_1
        case releaseDates = "release_dates"
    }
}

struct TMDBReleaseDate: Decodable {
    let certification: String?
    let type: Int?
    let note: String?
    let releaseDate: String?
    
    enum CodingKeys: String, CodingKey {
        case certification, type, note
        case releaseDate = "release_date"
    }
}

struct TMDBContentRatings: Decodable {
    let results: [TMDBContentRating]?
}

struct TMDBContentRating: Decodable {
    let iso3166_1: String
    let rating: String?
}

struct TMDBTranslations: Decodable {
    let translations: [TMDBTranslation]?
}

struct TMDBTranslation: Decodable {
    let iso3166_1: String
    let iso639_1: String
    let name: String
    let englishName: String
    let data: TMDBTranslationData?
    
    enum CodingKeys: String, CodingKey {
        case iso3166_1, iso639_1, name, data
        case englishName = "english_name"
    }
}

struct TMDBTranslationData: Decodable {
    let title: String?
    let overview: String?
    let homepage: String?
}

struct TMDBAlternativeTitles: Decodable {
    let titles: [TMDBAlternativeTitle]?
}

struct TMDBAlternativeTitle: Decodable {
    let iso3166_1: String
    let title: String
    let type: String?
}

struct TMDBCompany: Decodable, Identifiable {
    let id: Int
    let name: String
    let logoPath: String?
    let originCountry: String?
    
    var logoURL: URL? {
        guard let logoPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w185\(logoPath)")
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case logoPath = "logo_path"
        case originCountry = "origin_country"
    }
}

struct TMDBCountry: Decodable, Identifiable {
    let iso3166_1: String
    var id: String { iso3166_1 }
    let name: String
}

struct TMDBSpokenLanguage: Decodable, Identifiable {
    let iso639_1: String
    var id: String { iso639_1 }
    let englishName: String
    let name: String
    
    enum CodingKeys: String, CodingKey {
        case iso639_1, name
        case englishName = "english_name"
    }
}

// MARK: - TV Specific Models

struct TMDBSeason: Decodable, Identifiable {
    let id: Int
    let airDate: String?
    let episodeCount: Int?
    let name: String?
    let overview: String?
    let posterPath: String?
    let seasonNumber: Int?
    let voteAverage: Double?
    
    var posterURL: URL? {
        guard let posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, overview
        case airDate = "air_date"
        case episodeCount = "episode_count"
        case posterPath = "poster_path"
        case seasonNumber = "season_number"
        case voteAverage = "vote_average"
    }
}

struct TMDBEpisode: Decodable, Identifiable {
    let id: Int
    let airDate: String?
    let episodeNumber: Int?
    let name: String?
    let overview: String?
    let runtime: Int?
    let seasonNumber: Int?
    let showID: Int?
    let stillPath: String?
    let voteAverage: Double?
    let voteCount: Int?
    let crew: [TMDBCastMember]?
    let guestStars: [TMDBCastMember]?
    
    var stillURL: URL? {
        guard let stillPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w300\(stillPath)")
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, overview, runtime, crew
        case airDate = "air_date"
        case episodeNumber = "episode_number"
        case seasonNumber = "season_number"
        case showID = "show_id"
        case stillPath = "still_path"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case guestStars = "guest_stars"
    }
}

struct TMDBEpisodeGroup: Decodable, Identifiable {
    let id: String
    let name: String?
    let order: Int?
    let episodeCount: Int?
    let type: Int?
    let groups: [TMDBEpisodeGroupItem]?
    let network: TMDBNetwork?
    
    enum CodingKeys: String, CodingKey {
        case id, name, order
        case episodeCount = "episode_count"
        case type, groups, network
    }
}

struct TMDBEpisodeGroupItem: Decodable {
    let order: Int?
    let episodeCount: Int?
    let episodes: [TMDBEpisode]?
    
    enum CodingKeys: String, CodingKey {
        case order
        case episodeCount = "episode_count"
        case episodes
    }
}

struct TMDBNetwork: Decodable, Identifiable {
    let id: Int
    let name: String?
    let logoPath: String?
    let originCountry: String?
    
    var logoURL: URL? {
        guard let logoPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w185\(logoPath)")
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case logoPath = "logo_path"
        case originCountry = "origin_country"
    }
}

// MARK: - Person Models

struct TMDBPerson: Decodable, Identifiable {
    let id: Int
    let name: String?
    let biography: String?
    let birthday: String?
    let deathday: String?
    let placeOfBirth: String?
    let knownForDepartment: String?
    let gender: Int?
    let profilePath: String?
    let adult: Bool?
    let popularity: Double?
    let alsoKnownAs: [String]?
    let imdbID: String?
    let homepage: String?
    
    var profileURL: URL? {
        guard let profilePath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(profilePath)")
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, biography, birthday, deathday, gender, adult, popularity, homepage
        case placeOfBirth = "place_of_birth"
        case knownForDepartment = "known_for_department"
        case profilePath = "profile_path"
        case alsoKnownAs = "also_known_as"
        case imdbID = "imdb_id"
    }
}

struct TMDBPersonCredits: Decodable {
    let cast: [TMDBTitle]?
    let crew: [TMDBCrewCredit]?
}

struct TMDBCrewCredit: Decodable, Identifiable {
    let id: Int
    let creditID: String?
    let department: String?
    let job: String?
    let title: String?
    let name: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let firstAirDate: String?
    let mediaType: String?
    let voteAverage: Double?
    let popularity: Double?
    let episodeCount: Int?
    let seasonCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, department, job, title, name, overview, popularity
        case creditID = "credit_id"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case mediaType = "media_type"
        case voteAverage = "vote_average"
        case episodeCount = "episode_count"
        case seasonCount = "season_count"
    }
}

struct TMDBPersonImages: Decodable {
    let profiles: [TMDBImage]?
}

struct TMDBPersonExternalIDs: Decodable {
    let imdb_id: String?
    let facebook_id: String?
    let instagram_id: String?
    let twitter_id: String?
    let tiktok_id: String?
    let wikipedia_id: String?
    let freebase_mid: String?
    let freebase_id: String?
    let tvrage_id: Int?
}

// MARK: - Collection Models

struct TMDBCollection: Decodable, Identifiable {
    let id: Int
    let name: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let parts: [TMDBTitle]?
    
    var posterURL: URL? {
        guard let posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
    }
    var backdropURL: URL? {
        guard let backdropPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w1280\(backdropPath)")
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, overview, parts
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
    }
}

// MARK: - List Models

struct TMDBList: Decodable, Identifiable {
    let id: String
    let name: String?
    let description: String?
    let itemCount: Int?
    let posterPath: String?
    let backdropPath: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, description
        case itemCount = "item_count"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
    }
}

// MARK: - Page Models

struct TMDBPage<Item: Decodable>: Decodable {
    let page: Int
    let results: [Item]
    let totalPages: Int
    let totalResults: Int
    
    enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

struct TMDBGenresPage: Decodable {
    let genres: [TMDBGenre]
}

struct TMDBWatchProviderListPage: Decodable {
    let results: [TMDBWatchProvider]
}

struct TMDBProviderRegion: Decodable {
    let link: URL?
    let streaming: [TMDBWatchProvider]?
    let rent: [TMDBWatchProvider]?
    let buy: [TMDBWatchProvider]?
    let ads: [TMDBWatchProvider]?
    let freeOptions: [TMDBWatchProvider]?
    
    enum CodingKeys: String, CodingKey {
        case link, rent, buy, ads
        case streaming = "flatrate"
        case freeOptions = "free"
    }
}

struct TMDBWatchProvidersPage: Decodable {
    let results: [String: TMDBProviderRegion]
}

// MARK: - Error & Auth

enum TMDBError: LocalizedError {
    case missingToken
    case invalidResponse
    case httpStatus(Int)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .missingToken: "Add your TMDB API key or Read Access Token in Settings to get started."
        case .invalidResponse: "TMDB returned an unreadable response."
        case .httpStatus(401): "That TMDB credential was not accepted. Check it in Settings."
        case .httpStatus(let status): "TMDB request failed (\(status)). Please try again."
        case .decodingError(let error): "Failed to decode response: \(error.localizedDescription)"
        }
    }
}

enum TMDBAuthentication {
    static func configure(_ request: inout URLRequest, credential: String) {
        if credential.count == 32 {
            var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            var queryItems = components.queryItems ?? []
            queryItems.append(URLQueryItem(name: "api_key", value: credential))
            components.queryItems = queryItems
            request.url = components.url
        } else {
            request.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")
        }
    }
}

// MARK: - Service Protocol

protocol TMDBServicing {
    // Trending
    func trending(mediaType: String?, timeWindow: String) async throws -> [TMDBTitle]
    
    // Movies
    func popularMovies() async throws -> [TMDBTitle]
    func topRatedMovies() async throws -> [TMDBTitle]
    func nowPlayingMovies(region: String?) async throws -> [TMDBTitle]
    func upcomingMovies(region: String?) async throws -> [TMDBTitle]
    
    // TV
    func popularShows() async throws -> [TMDBTitle]
    func topRatedShows() async throws -> [TMDBTitle]
    func onTheAirShows() async throws -> [TMDBTitle]
    func airingTodayShows() async throws -> [TMDBTitle]
    
    // Discovery
    func genres(for type: String) async throws -> [TMDBGenre]
    func providers(for type: String, region: String) async throws -> [TMDBWatchProvider]
    func discover(type: String, filters: TMDBDiscoveryFilters, region: String) async throws -> [TMDBTitle]
    
    // Details
    func details(for title: TMDBTitle) async throws -> TMDBTitleDetails
    func watchProviders(for title: TMDBTitle, region: String) async throws -> TMDBProviderRegion?
    
    // TV Specific
    func seasonDetails(showID: Int, seasonNumber: Int) async throws -> TMDBSeason
    func episodeDetails(showID: Int, seasonNumber: Int, episodeNumber: Int) async throws -> TMDBEpisode
    
    // Search
    func search(_ query: String) async throws -> [TMDBTitle]
    func searchMovies(_ query: String) async throws -> [TMDBTitle]
    func searchTV(_ query: String) async throws -> [TMDBTitle]
    func searchPeople(_ query: String) async throws -> [TMDBPerson]
    
    // People
    func popularPeople() async throws -> [TMDBPerson]
    func personDetails(id: Int) async throws -> TMDBPerson
    func personCredits(id: Int) async throws -> TMDBPersonCredits
    func personImages(id: Int) async throws -> TMDBPersonImages
    func personExternalIDs(id: Int) async throws -> TMDBPersonExternalIDs
    
    // Videos & Trailers
    func videos(for title: TMDBTitle) async throws -> [TMDBVideo]
    func trailerURL(for title: TMDBTitle) async throws -> URL?
    
    // External IDs
    func fetchExternalIDs(for title: TMDBTitle) async throws -> TMDBExternalIDs?
    func enrichWithIMDBID(_ title: TMDBTitle) async throws -> TMDBTitle
    
    // Images
    func images(for title: TMDBTitle) async throws -> TMDBImages
    
    // Recommendations & Similar
    func recommendations(for title: TMDBTitle) async throws -> [TMDBTitle]
    func similar(for title: TMDBTitle) async throws -> [TMDBTitle]
    
    // Reviews
    func reviews(for title: TMDBTitle) async throws -> TMDBReviewsPage
    
    // Keywords
    func keywords(for title: TMDBTitle) async throws -> TMDBKeywords
    
    // Release Dates / Content Ratings
    func releaseDates(for title: TMDBTitle) async throws -> TMDBReleaseDates
    func contentRatings(for title: TMDBTitle) async throws -> TMDBContentRatings
    
    // Translations & Alternative Titles
    func translations(for title: TMDBTitle) async throws -> TMDBTranslations
    func alternativeTitles(for title: TMDBTitle) async throws -> TMDBAlternativeTitles
    
    // Certifications
    func movieCertifications() async throws -> [String: [TMDBReleaseDate]]
    func tvCertifications() async throws -> [String: [TMDBContentRating]]
    
    // Collections
    func collectionDetails(id: Int) async throws -> TMDBCollection
    
    // Account (requires session ID)
    // func accountStates(...)
}

// MARK: - Client Implementation

struct TMDBClient: TMDBServicing {
    let token: String
    private let baseURL = URL(string: "https://api.themoviedb.org/3")!
    
    // MARK: - Trending
    
    func trending(mediaType: String? = nil, timeWindow: String = "week") async throws -> [TMDBTitle] {
        let path = mediaType != nil ? "/trending/\(mediaType!)/\(timeWindow)" : "/trending/all/\(timeWindow)"
        return try await titles(path)
    }
    
    // MARK: - Movies
    
    func popularMovies() async throws -> [TMDBTitle] {
        try await titles("/movie/popular")
    }
    
    func topRatedMovies() async throws -> [TMDBTitle] {
        try await titles("/movie/top_rated")
    }
    
    func nowPlayingMovies(region: String? = nil) async throws -> [TMDBTitle] {
        var components = URLComponents(url: baseURL.appending(path: "movie/now_playing"), resolvingAgainstBaseURL: false)!
        if let region = region {
            components.queryItems = [URLQueryItem(name: "region", value: region.uppercased())]
        }
        return try await titles(components.url!.path)
    }
    
    func upcomingMovies(region: String? = nil) async throws -> [TMDBTitle] {
        var components = URLComponents(url: baseURL.appending(path: "movie/upcoming"), resolvingAgainstBaseURL: false)!
        if let region = region {
            components.queryItems = [URLQueryItem(name: "region", value: region.uppercased())]
        }
        return try await titles(components.url!.path)
    }
    
    // MARK: - TV
    
    func popularShows() async throws -> [TMDBTitle] {
        try await titles("/tv/popular")
    }
    
    func topRatedShows() async throws -> [TMDBTitle] {
        try await titles("/tv/top_rated")
    }
    
    func onTheAirShows() async throws -> [TMDBTitle] {
        try await titles("/tv/on_the_air")
    }
    
    func airingTodayShows() async throws -> [TMDBTitle] {
        try await titles("/tv/airing_today")
    }
    
    // MARK: - Discovery
    
    func genres(for type: String) async throws -> [TMDBGenre] {
        let page: TMDBGenresPage = try await get("/genre/\(type)/list")
        return page.genres
    }
    
    func providers(for type: String, region: String) async throws -> [TMDBWatchProvider] {
        var components = URLComponents(url: baseURL.appending(path: "watch/providers/\(type)"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "watch_region", value: region.uppercased())]
        let page: TMDBWatchProviderListPage = try await request(url: components.url!)
        return page.results.sorted { $0.providerName.localizedCaseInsensitiveCompare($1.providerName) == .orderedAscending }
    }
    
    func discover(type: String, filters: TMDBDiscoveryFilters, region: String) async throws -> [TMDBTitle] {
        let page: TMDBPage<TMDBTitle> = try await request(url: Self.discoverURL(type: type, filters: filters, region: region))
        return page.results
    }
    
    static func discoverURL(type: String, filters: TMDBDiscoveryFilters, region: String) -> URL {
        var components = URLComponents(string: "https://api.themoviedb.org/3/discover/\(type)")!
        var queryItems = [URLQueryItem(name: "sort_by", value: filters.sortBy)]
        if let genreID = filters.genreID {
            queryItems.append(URLQueryItem(name: "with_genres", value: String(genreID)))
        }
        if let year = filters.year {
            let key = type == "tv" ? "first_air_date_year" : "primary_release_year"
            queryItems.append(URLQueryItem(name: key, value: String(year)))
        }
        if let providerID = filters.providerID {
            queryItems.append(URLQueryItem(name: "with_watch_providers", value: String(providerID)))
            queryItems.append(URLQueryItem(name: "watch_region", value: region.uppercased()))
        }
        if let certification = filters.certification {
            let key = type == "tv" ? "certification_country" : "certification_country"
            queryItems.append(URLQueryItem(name: key, value: region.uppercased()))
            queryItems.append(URLQueryItem(name: "certification", value: certification))
        }
        if let keywordIDs = filters.keywordIDs, !keywordIDs.isEmpty {
            queryItems.append(URLQueryItem(name: "with_keywords", value: keywordIDs.map(String.init).joined(separator: ",")))
        }
        if let includeAdult = filters.includeAdult {
            queryItems.append(URLQueryItem(name: "include_adult", value: String(includeAdult)))
        }
        if let language = filters.language {
            queryItems.append(URLQueryItem(name: "language", value: language))
        }
        if let page = filters.page {
            queryItems.append(URLQueryItem(name: "page", value: String(page)))
        }
        components.queryItems = queryItems
        return components.url!
    }
    
    // MARK: - Details
    
    func details(for title: TMDBTitle) async throws -> TMDBTitleDetails {
        var components = URLComponents(url: baseURL.appending(path: "\(title.type)/\(title.id)"), resolvingAgainstBaseURL: false)!
        let creditsEndpoint = title.type == "tv" ? "aggregate_credits" : "credits"
        components.queryItems = [
            URLQueryItem(name: "append_to_response", value: "\(creditsEndpoint),external_ids,videos,images,recommendations,similar,reviews,keywords,release_dates,content_ratings,translations,alternative_titles")
        ]
        return try await request(url: components.url!)
    }
    
    func watchProviders(for title: TMDBTitle, region: String) async throws -> TMDBProviderRegion? {
        let page: TMDBWatchProvidersPage = try await get("/\(title.type)/\(title.id)/watch/providers")
        return page.results[region.uppercased()]
    }
    
    // MARK: - TV Specific
    
    func seasonDetails(showID: Int, seasonNumber: Int) async throws -> TMDBSeason {
        return try await get("/tv/\(showID)/season/\(seasonNumber)")
    }
    
    func episodeDetails(showID: Int, seasonNumber: Int, episodeNumber: Int) async throws -> TMDBEpisode {
        return try await get("/tv/\(showID)/season/\(seasonNumber)/episode/\(episodeNumber)")
    }
    
    // MARK: - Search
    
    func search(_ query: String) async throws -> [TMDBTitle] {
        var components = URLComponents(url: baseURL.appending(path: "search/multi"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "query", value: query)]
        let page: TMDBPage<TMDBTitle> = try await request(url: components.url!)
        return page.results.filter { $0.type == "movie" || $0.type == "tv" }
    }
    
    func searchMovies(_ query: String) async throws -> [TMDBTitle] {
        var components = URLComponents(url: baseURL.appending(path: "search/movie"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "query", value: query)]
        let page: TMDBPage<TMDBTitle> = try await request(url: components.url!)
        return page.results
    }
    
    func searchTV(_ query: String) async throws -> [TMDBTitle] {
        var components = URLComponents(url: baseURL.appending(path: "search/tv"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "query", value: query)]
        let page: TMDBPage<TMDBTitle> = try await request(url: components.url!)
        return page.results
    }
    
    func searchPeople(_ query: String) async throws -> [TMDBPerson] {
        var components = URLComponents(url: baseURL.appending(path: "search/person"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "query", value: query)]
        let page: TMDBPage<TMDBPerson> = try await request(url: components.url!)
        return page.results
    }
    
    // MARK: - People
    
    func popularPeople() async throws -> [TMDBPerson] {
        let page: TMDBPage<TMDBPerson> = try await get("/person/popular")
        return page.results
    }
    
    func personDetails(id: Int) async throws -> TMDBPerson {
        return try await get("/person/\(id)")
    }
    
    func personCredits(id: Int) async throws -> TMDBPersonCredits {
        return try await get("/person/\(id)/combined_credits")
    }
    
    func personImages(id: Int) async throws -> TMDBPersonImages {
        return try await get("/person/\(id)/images")
    }
    
    func personExternalIDs(id: Int) async throws -> TMDBPersonExternalIDs {
        return try await get("/person/\(id)/external_ids")
    }
    
    // MARK: - Videos & Trailers
    
    func videos(for title: TMDBTitle) async throws -> [TMDBVideo] {
        let page: TMDBVideoPage = try await get("/\(title.type)/\(title.id)/videos")
        return page.results
    }
    
    func trailerURL(for title: TMDBTitle) async throws -> URL? {
        let videos = try await self.videos(for: title)
        guard let trailer = videos.first(where: { $0.site == "YouTube" && $0.type == "Trailer" && $0.official == true }) ??
                videos.first(where: { $0.site == "YouTube" && $0.type == "Trailer" }) else {
            return nil
        }
        return URL(string: "https://www.youtube.com/watch?v=\(trailer.key)")
    }
    
    // MARK: - External IDs
    
    func fetchExternalIDs(for title: TMDBTitle) async throws -> TMDBExternalIDs? {
        return try await get("/\(title.type)/\(title.id)/external_ids")
    }
    
    func enrichWithIMDBID(_ title: TMDBTitle) async throws -> TMDBTitle {
        var enriched = title
        enriched.imdbID = (try await fetchExternalIDs(for: title))?.imdb_id
        return enriched
    }
    
    // MARK: - Images
    
    func images(for title: TMDBTitle) async throws -> TMDBImages {
        return try await get("/\(title.type)/\(title.id)/images")
    }
    
    // MARK: - Recommendations & Similar
    
    func recommendations(for title: TMDBTitle) async throws -> [TMDBTitle] {
        try await titles("/\(title.type)/\(title.id)/recommendations")
    }
    
    func similar(for title: TMDBTitle) async throws -> [TMDBTitle] {
        try await titles("/\(title.type)/\(title.id)/similar")
    }
    
    // MARK: - Reviews
    
    func reviews(for title: TMDBTitle) async throws -> TMDBReviewsPage {
        return try await get("/\(title.type)/\(title.id)/reviews")
    }
    
    // MARK: - Keywords
    
    func keywords(for title: TMDBTitle) async throws -> TMDBKeywords {
        return try await get("/\(title.type)/\(title.id)/keywords")
    }
    
    // MARK: - Release Dates & Content Ratings
    
    func releaseDates(for title: TMDBTitle) async throws -> TMDBReleaseDates {
        return try await get("/\(title.type)/\(title.id)/release_dates")
    }
    
    func contentRatings(for title: TMDBTitle) async throws -> TMDBContentRatings {
        return try await get("/\(title.type)/\(title.id)/content_ratings")
    }
    
    // MARK: - Translations & Alternative Titles
    
    func translations(for title: TMDBTitle) async throws -> TMDBTranslations {
        return try await get("/\(title.type)/\(title.id)/translations")
    }
    
    func alternativeTitles(for title: TMDBTitle) async throws -> TMDBAlternativeTitles {
        return try await get("/\(title.type)/\(title.id)/alternative_titles")
    }
    
    // MARK: - Certifications
    
    func movieCertifications() async throws -> [String: [TMDBReleaseDate]] {
        struct CertPage: Decodable {
            let certifications: [String: [TMDBReleaseDate]]
        }
        let page: CertPage = try await get("/certification/movie/list")
        return page.certifications
    }
    
    func tvCertifications() async throws -> [String: [TMDBContentRating]] {
        struct CertPage: Decodable {
            let certifications: [String: [TMDBContentRating]]
        }
        let page: CertPage = try await get("/certification/tv/list")
        return page.certifications
    }
    
    // MARK: - Collections
    
    func collectionDetails(id: Int) async throws -> TMDBCollection {
        return try await get("/collection/\(id)")
    }
    
    // MARK: - Private Helpers
    
    private func get<Item: Decodable>(_ path: String) async throws -> Item {
        let normalizedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return try await request(url: baseURL.appending(path: normalizedPath))
    }
    
    private func titles(_ path: String) async throws -> [TMDBTitle] {
        let page: TMDBPage<TMDBTitle> = try await get(path)
        return page.results
    }
    
    private func request<Item: Decodable>(url: URL) async throws -> Item {
        guard !token.isEmpty else { throw TMDBError.missingToken }
        var request = URLRequest(url: url)
        TMDBAuthentication.configure(&request, credential: token)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw TMDBError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else { throw TMDBError.httpStatus(response.statusCode) }
        do {
            return try JSONDecoder().decode(Item.self, from: data)
        } catch {
            throw TMDBError.decodingError(error)
        }
    }
}

// MARK: - Token Vault

enum TokenVault {
    private static let service = "com.example.streami.tmdb"
    private static let account = "read-access-token"
    private static let defaultKey = "4e44d9029b1270a757cddc766a1bcb63"
    
    static func read() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else { return defaultKey }
        return token
    }
    
    static func save(_ token: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let data = Data(token.utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var insertion = query
            insertion[kSecValueData as String] = data
            let addStatus = SecItemAdd(insertion as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError(status: addStatus) }
        } else if status != errSecSuccess {
            throw KeychainError(status: status)
        }
    }
    
    static func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }
    
    private struct KeychainError: LocalizedError {
        let status: OSStatus
        var errorDescription: String? { "Could not store the token in Keychain (\(status))." }
    }
}