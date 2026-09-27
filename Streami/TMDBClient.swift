import Foundation
import Security

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

    var displayTitle: String { title ?? name ?? "Untitled" }
    var type: String { mediaType ?? (name == nil ? "movie" : "tv") }
    var listID: String { "\(type)-\(id)" }
    var year: String { String((releaseDate ?? firstAirDate ?? "").prefix(4)) }
    var posterURL: URL? { imageURL(path: posterPath, size: "w500") }
    var backdropURL: URL? { imageURL(path: backdropPath, size: "w1280") }

    enum CodingKeys: String, CodingKey {
        case id, title, name, overview
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

    var creditDescription: String {
        character ?? roles?.first?.character ?? "Cast"
    }

    var profileURL: URL? {
        guard let profilePath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w185\(profilePath)")
    }

    enum CodingKeys: String, CodingKey {
        case id, name, character, roles
        case profilePath = "profile_path"
    }
}

struct TMDBCredits: Decodable {
    let cast: [TMDBCastMember]?
}

struct TMDBTitleDetails: Decodable {
    let genres: [TMDBGenre]?
    let runtime: Int?
    let episodeRunTime: [Int]?
    let credits: TMDBCredits?
    let aggregateCredits: TMDBCredits?

    var cast: [TMDBCastMember] { Array((credits?.cast ?? aggregateCredits?.cast ?? []).prefix(12)) }
    var displayRuntime: Int? { runtime ?? episodeRunTime?.first }

    enum CodingKeys: String, CodingKey {
        case genres, runtime, credits
        case episodeRunTime = "episode_run_time"
        case aggregateCredits = "aggregate_credits"
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
        case link, rent, buy, ads, streaming = "flatrate", freeOptions = "free"
    }
}

struct TMDBWatchProvidersPage: Decodable {
    let results: [String: TMDBProviderRegion]
}

private struct TMDBPage<Item: Decodable>: Decodable {
    let results: [Item]
}

private struct TMDBVideoPage: Decodable {
    let results: [TMDBVideo]
}

private struct TMDBVideo: Decodable {
    let key: String
    let site: String
    let type: String
}

enum TMDBError: LocalizedError {
    case missingToken
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .missingToken: "Add your TMDB API key or Read Access Token in Settings to get started."
        case .invalidResponse: "TMDB returned an unreadable response."
        case .httpStatus(401): "That TMDB credential was not accepted. Check it in Settings."
        case .httpStatus(let status): "TMDB request failed (\(status)). Please try again."
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

protocol TMDBServicing {
    func trending() async throws -> [TMDBTitle]
    func popularMovies() async throws -> [TMDBTitle]
    func popularShows() async throws -> [TMDBTitle]
    func recommendations(for title: TMDBTitle) async throws -> [TMDBTitle]
    func genres(for type: String) async throws -> [TMDBGenre]
    func providers(for type: String, region: String) async throws -> [TMDBWatchProvider]
    func discover(type: String, filters: TMDBDiscoveryFilters, region: String) async throws -> [TMDBTitle]
    func details(for title: TMDBTitle) async throws -> TMDBTitleDetails
    func watchProviders(for title: TMDBTitle, region: String) async throws -> TMDBProviderRegion?
    func search(_ query: String) async throws -> [TMDBTitle]
    func trailerURL(for title: TMDBTitle) async throws -> URL?
}

struct TMDBClient: TMDBServicing {
    let token: String
    private let baseURL = URL(string: "https://api.themoviedb.org/3")!

    func trending() async throws -> [TMDBTitle] {
        try await titles("/trending/all/week")
    }

    func popularMovies() async throws -> [TMDBTitle] {
        try await titles("/movie/popular")
    }

    func popularShows() async throws -> [TMDBTitle] {
        try await titles("/tv/popular")
    }

    func recommendations(for title: TMDBTitle) async throws -> [TMDBTitle] {
        try await titles("/\(title.type)/\(title.id)/recommendations")
    }

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
        components.queryItems = queryItems
        return components.url!
    }

    func details(for title: TMDBTitle) async throws -> TMDBTitleDetails {
        var components = URLComponents(url: baseURL.appending(path: "\(title.type)/\(title.id)"), resolvingAgainstBaseURL: false)!
        let creditsEndpoint = title.type == "tv" ? "aggregate_credits" : "credits"
        components.queryItems = [URLQueryItem(name: "append_to_response", value: creditsEndpoint)]
        return try await request(url: components.url!)
    }

    func watchProviders(for title: TMDBTitle, region: String) async throws -> TMDBProviderRegion? {
        let page: TMDBWatchProvidersPage = try await get("/\(title.type)/\(title.id)/watch/providers")
        return page.results[region.uppercased()]
    }

    func search(_ query: String) async throws -> [TMDBTitle] {
        var components = URLComponents(url: baseURL.appending(path: "search/multi"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "query", value: query)]
        let page: TMDBPage<TMDBTitle> = try await request(url: components.url!)
        return page.results.filter { $0.type == "movie" || $0.type == "tv" }
    }

    func trailerURL(for title: TMDBTitle) async throws -> URL? {
        let videos: TMDBVideoPage = try await get("/\(title.type)/\(title.id)/videos")
        guard let trailer = videos.results.first(where: { $0.site == "YouTube" && $0.type == "Trailer" }) else {
            return nil
        }
        return URL(string: "https://www.youtube.com/watch?v=\(trailer.key)")
    }

    func fetchExternalIDs(for title: TMDBTitle) async throws -> String? {
        struct ExternalIDs: Decodable {
            let imdb_id: String?
        }
        let externalIDs: ExternalIDs = try await get("/\(title.type)/\(title.id)/external_ids")
        return externalIDs.imdb_id
    }

    func enrichWithIMDBID(_ title: TMDBTitle) async throws -> TMDBTitle {
        var enriched = title
        enriched.imdbID = try await fetchExternalIDs(for: title)
        return enriched
    }

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
        return try JSONDecoder().decode(Item.self, from: data)
    }
}

enum TokenVault {
    private static let service = "com.example.streami.tmdb"
    private static let account = "read-access-token"

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
              let token = String(data: data, encoding: .utf8) else { return "" }
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
