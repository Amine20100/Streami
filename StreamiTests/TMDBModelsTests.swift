import XCTest
import Foundation
@testable import Streami

final class TMDBModelsTests: XCTestCase {
    func testWatchProvidersDecodeCountryAndAvailabilityTypes() throws {
        let json = """
        {
          "id": 550,
          "results": {
            "US": {
              "link": "https://www.themoviedb.org/movie/550/watch?locale=US",
              "flatrate": [{
                "logo_path": "/provider.png",
                "provider_id": 119,
                "provider_name": "Example Stream",
                "display_priority": 1
              }],
              "free": [{
                "logo_path": "/free.png",
                "provider_id": 7,
                "provider_name": "Example Free",
                "display_priority": 2
              }]
            }
          }
        }
        """

        let page = try JSONDecoder().decode(TMDBWatchProvidersPage.self, from: Data(json.utf8))
        let region = try XCTUnwrap(page.results["US"])

        XCTAssertEqual(region.link?.host, "www.themoviedb.org")
        XCTAssertEqual(region.streaming?.first?.providerName, "Example Stream")
        XCTAssertEqual(region.freeOptions?.first?.providerID, 7)
    }

    func testMovieAndSeriesIDsDoNotCollideInLists() throws {
        let movie = try JSONDecoder().decode(TMDBTitle.self, from: Data(#"{"id":42,"title":"Example","media_type":"movie"}"#.utf8))
        let series = try JSONDecoder().decode(TMDBTitle.self, from: Data(#"{"id":42,"name":"Example","media_type":"tv"}"#.utf8))

        XCTAssertNotEqual(movie.listID, series.listID)
    }

    func testV3APIKeyUsesQueryAuthentication() throws {
        var request = URLRequest(url: URL(string: "https://api.themoviedb.org/3/movie/550")!)
        TMDBAuthentication.configure(&request, credential: String(repeating: "a", count: 32))

        let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "api_key" })?.value, String(repeating: "a", count: 32))
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    func testReadAccessTokenUsesBearerAuthentication() {
        var request = URLRequest(url: URL(string: "https://api.themoviedb.org/3/movie/550")!)
        TMDBAuthentication.configure(&request, credential: "read-access-token")

        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer read-access-token")
    }

    func testMovieDetailsDecodeGenresRuntimeAndCast() throws {
      let json = #"{"genres":[{"id":18,"name":"Drama"}],"runtime":123,"credits":{"cast":[{"id":9,"name":"Example Actor","character":"Lead","profile_path":"/actor.jpg","order":0}]}}"#
      let details = try JSONDecoder().decode(TMDBTitleDetails.self, from: Data(json.utf8))

      XCTAssertEqual(details.genres?.first?.name, "Drama")
      XCTAssertEqual(details.displayRuntime, 123)
      XCTAssertEqual(details.cast.first?.creditDescription, "Lead")
      XCTAssertEqual(details.cast.first?.profileURL?.path, "/t/p/w185/actor.jpg")
    }

      func testDiscoverURLIncludesGenreYearProviderRegionAndSort() throws {
        let url = TMDBClient.discoverURL(
          type: "movie",
          filters: TMDBDiscoveryFilters(genreID: 18, year: 2020, sortBy: "vote_average.desc", providerID: 8),
          region: "gb"
        )
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) })

        XCTAssertEqual(components.path, "/3/discover/movie")
        XCTAssertEqual(query["with_genres"], "18")
        XCTAssertEqual(query["primary_release_year"], "2020")
        XCTAssertEqual(query["with_watch_providers"], "8")
        XCTAssertEqual(query["watch_region"], "GB")
        XCTAssertEqual(query["sort_by"], "vote_average.desc")
      }

    @MainActor
    func testGuestWatchlistPersistsAcrossStoreRecreation() throws {
        let suiteName = "StreamiTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let persistence = UserDefaultsWatchlistStore(defaults: defaults)
        let title = try JSONDecoder().decode(
            TMDBTitle.self,
            from: Data(#"{"id":42,"title":"Example","media_type":"movie"}"#.utf8)
        )
        let collectionPersistence = UserDefaultsWatchlistCollectionPersistence(defaults: defaults)
        let firstStore = WatchlistStore(persistence: persistence, collectionPersistence: collectionPersistence)
        firstStore.toggle(title)

        let reloadedStore = WatchlistStore(persistence: persistence, collectionPersistence: collectionPersistence)
        XCTAssertTrue(reloadedStore.contains(title))
        reloadedStore.toggle(title)
        XCTAssertFalse(WatchlistStore(persistence: persistence, collectionPersistence: collectionPersistence).contains(title))
      }

      @MainActor
      func testGuestWatchlistCollectionsPersistAndFilterTitles() throws {
        let suiteName = "StreamiCollectionTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let persistence = UserDefaultsWatchlistStore(defaults: defaults)
        let collectionPersistence = UserDefaultsWatchlistCollectionPersistence(defaults: defaults)
        let title = try JSONDecoder().decode(
          TMDBTitle.self,
          from: Data(#"{"id":42,"title":"Example","genre_ids":[18],"media_type":"movie"}"#.utf8)
        )
        let store = WatchlistStore(persistence: persistence, collectionPersistence: collectionPersistence)
        store.toggle(title)

        XCTAssertTrue(store.createCollection(named: "Drama Night"))
        let collectionID = store.activeCollectionID
        store.setMembership(title, in: collectionID, isMember: true)
        XCTAssertEqual(store.activeTitles.map(\.listID), [title.listID])

        let restored = WatchlistStore(persistence: persistence, collectionPersistence: collectionPersistence)
        XCTAssertEqual(restored.activeCollectionID, collectionID)
        XCTAssertEqual(restored.activeTitles.map(\.listID), [title.listID])
      }

      func testPersonalizedCatalogRanksSharedGenresAndExcludesSavedTitles() throws {
        let saved = try decodeTitle(#"{"id":1,"title":"Saved","genre_ids":[18,53],"media_type":"movie"}"#)
        let unrelated = try decodeTitle(#"{"id":2,"title":"Unrelated","genre_ids":[35],"vote_average":9.8,"vote_count":9000,"media_type":"movie"}"#)
        let related = try decodeTitle(#"{"id":3,"title":"Related","genre_ids":[18],"vote_average":7.2,"vote_count":1000,"popularity":500,"media_type":"movie"}"#)
        let mostRelated = try decodeTitle(#"{"id":4,"title":"Most related","genre_ids":[18,53],"vote_average":6.5,"vote_count":20,"popularity":10,"media_type":"movie"}"#)

        let ranked = PersonalizedCatalog.rank([unrelated, related, mostRelated, saved], against: [saved])

        XCTAssertEqual(ranked.map(\.displayTitle), ["Most related", "Related"])
      }

      private func decodeTitle(_ json: String) throws -> TMDBTitle {
        try JSONDecoder().decode(TMDBTitle.self, from: Data(json.utf8))
      }

      @MainActor
      func testNewestSearchResponseWins() async throws {
        let suiteName = "StreamiSearchTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let services = AppServices(
          credentialStore: TestCredentialStore(),
          watchlistPersistence: UserDefaultsWatchlistStore(defaults: defaults),
          watchlistCollectionPersistence: UserDefaultsWatchlistCollectionPersistence(defaults: defaults),
          clientFactory: { _ in DelayedSearchService() },
          defaults: defaults
        )
        let earlierSearch = Task { await services.search.search("slow") }
        try await Task.sleep(for: .milliseconds(10))
        await services.search.search("latest")
        await earlierSearch.value

        XCTAssertEqual(services.search.results.first?.displayTitle, "latest")
      }
}

    private struct TestCredentialStore: CredentialStoring {
      func load() -> String { "test-credential" }
      func save(_ credential: String) throws {}
      func remove() throws {}
    }

    private struct DelayedSearchService: TMDBServicing {
      func trending(mediaType: String?, timeWindow: String) async throws -> [TMDBTitle] { [] }
      func popularMovies() async throws -> [TMDBTitle] { [] }
      func topRatedMovies() async throws -> [TMDBTitle] { [] }
      func nowPlayingMovies(region: String?) async throws -> [TMDBTitle] { [] }
      func upcomingMovies(region: String?) async throws -> [TMDBTitle] { [] }
      func popularShows() async throws -> [TMDBTitle] { [] }
      func topRatedShows() async throws -> [TMDBTitle] { [] }
      func onTheAirShows() async throws -> [TMDBTitle] { [] }
      func airingTodayShows() async throws -> [TMDBTitle] { [] }
      func recommendations(for title: TMDBTitle) async throws -> [TMDBTitle] { [] }
      func genres(for type: String) async throws -> [TMDBGenre] { [] }
      func providers(for type: String, region: String) async throws -> [TMDBWatchProvider] { [] }
      func discover(type: String, filters: TMDBDiscoveryFilters, region: String) async throws -> [TMDBTitle] { [] }
      func details(for title: TMDBTitle) async throws -> TMDBTitleDetails {
        TMDBTitleDetails(
          genres: nil, runtime: nil, episodeRunTime: nil, credits: nil, aggregateCredits: nil,
          externalIDs: nil, videos: nil, images: nil, recommendations: nil, similar: nil,
          reviews: nil, keywords: nil, releaseDates: nil, contentRatings: nil,
          translations: nil, alternativeTitles: nil, status: nil, tagline: nil,
          homepage: nil, productionCompanies: nil, productionCountries: nil,
          spokenLanguages: nil, budget: nil, revenue: nil, originCountry: nil,
          originalLanguage: nil, inProduction: nil, lastAirDate: nil,
          nextEpisodeToAir: nil, numberOfSeasons: nil, numberOfEpisodes: nil,
          seasons: nil, episodeGroups: nil, type: nil
        )
      }
      func watchProviders(for title: TMDBTitle, region: String) async throws -> TMDBProviderRegion? { nil }
      func seasonDetails(showID: Int, seasonNumber: Int) async throws -> TMDBSeason {
        TMDBSeason(id: 1, airDate: nil, episodeCount: nil, name: nil, overview: nil, posterPath: nil, seasonNumber: 1, voteAverage: nil, episodes: nil)
      }
      func episodeDetails(showID: Int, seasonNumber: Int, episodeNumber: Int) async throws -> TMDBEpisode {
        TMDBEpisode(id: 1, airDate: nil, episodeNumber: 1, name: nil, overview: nil, runtime: nil, seasonNumber: 1, showID: 1, stillPath: nil, voteAverage: nil, voteCount: nil, crew: nil, guestStars: nil)
      }
      func search(_ query: String) async throws -> [TMDBTitle] {
        if query == "slow" { try await Task.sleep(for: .milliseconds(80)) }
        let data = try JSONSerialization.data(withJSONObject: [
          "id": 42,
          "title": query,
          "media_type": "movie"
        ])
        return [try JSONDecoder().decode(TMDBTitle.self, from: data)]
      }
      func searchMovies(_ query: String) async throws -> [TMDBTitle] { [] }
      func searchTV(_ query: String) async throws -> [TMDBTitle] { [] }
      func searchPeople(_ query: String) async throws -> [TMDBPerson] { [] }
      func popularPeople() async throws -> [TMDBPerson] { [] }
      func personDetails(id: Int) async throws -> TMDBPerson {
        TMDBPerson(id: 1, name: "Test", biography: nil, birthday: nil, deathday: nil, placeOfBirth: nil, knownForDepartment: nil, gender: nil, profilePath: nil, adult: nil, popularity: nil, alsoKnownAs: nil, imdbID: nil, homepage: nil)
      }
      func personCredits(id: Int) async throws -> TMDBPersonCredits { TMDBPersonCredits(cast: nil, crew: nil) }
      func personImages(id: Int) async throws -> TMDBPersonImages { TMDBPersonImages(profiles: nil) }
      func personExternalIDs(id: Int) async throws -> TMDBPersonExternalIDs { TMDBPersonExternalIDs(imdb_id: nil, facebook_id: nil, instagram_id: nil, twitter_id: nil, tiktok_id: nil, wikipedia_id: nil, freebase_mid: nil, freebase_id: nil, tvrage_id: nil) }
      func videos(for title: TMDBTitle) async throws -> [TMDBVideo] { [] }
      func trailerURL(for title: TMDBTitle) async throws -> URL? { nil }
      func fetchExternalIDs(for title: TMDBTitle) async throws -> TMDBExternalIDs? { TMDBExternalIDs(imdb_id: nil, facebook_id: nil, instagram_id: nil, twitter_id: nil, tiktok_id: nil, wikipedia_id: nil) }
      func enrichWithIMDBID(_ title: TMDBTitle) async throws -> TMDBTitle { title }
      func images(for title: TMDBTitle) async throws -> TMDBImages { TMDBImages(backdrops: nil, posters: nil, logos: nil) }
      func similar(for title: TMDBTitle) async throws -> [TMDBTitle] { [] }
      func reviews(for title: TMDBTitle) async throws -> TMDBReviewsPage { TMDBReviewsPage(page: 1, results: [], totalPages: 0, totalResults: 0) }
      func keywords(for title: TMDBTitle) async throws -> TMDBKeywords { TMDBKeywords(keywords: nil) }
      func releaseDates(for title: TMDBTitle) async throws -> TMDBReleaseDates { TMDBReleaseDates(results: nil) }
      func contentRatings(for title: TMDBTitle) async throws -> TMDBContentRatings { TMDBContentRatings(results: nil) }
      func translations(for title: TMDBTitle) async throws -> TMDBTranslations { TMDBTranslations(translations: nil) }
      func alternativeTitles(for title: TMDBTitle) async throws -> TMDBAlternativeTitles { TMDBAlternativeTitles(titles: nil) }
      func movieCertifications() async throws -> [String: [TMDBReleaseDate]] { [:] }
      func tvCertifications() async throws -> [String: [TMDBContentRating]] { [:] }
      func collectionDetails(id: Int) async throws -> TMDBCollection { TMDBCollection(id: 1, name: "Test", overview: nil, posterPath: nil, backdropPath: nil, parts: nil) }
    }