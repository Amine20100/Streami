import SwiftUI
import Kingfisher
import Lottie

private enum StreamiStyle {
    static let background = Color(red: 0.035, green: 0.045, blue: 0.06)
    static let surface = Color(red: 0.09, green: 0.105, blue: 0.125)
    static let accent = Color(red: 1.0, green: 0.34, blue: 0.19)
    static let muted = Color(red: 0.62, green: 0.65, blue: 0.7)
}

private enum DiscoverMode: String, CaseIterable, Identifiable {
    case forYou = "For You"
    case movies = "Movies"
    case series = "Series"

    var id: String { rawValue }
}

private enum CatalogSort: String, CaseIterable, Identifiable {
    case popular = "Most popular"
    case topRated = "Top rated"
    case newest = "Newest"

    var id: String { rawValue }

    func apiValue(for type: String) -> String {
        switch self {
        case .popular: "popularity.desc"
        case .topRated: "vote_average.desc"
        case .newest: type == "tv" ? "first_air_date.desc" : "primary_release_date.desc"
        }
    }
}

private enum SearchFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case movies = "Movies"
    case series = "Series"

    var id: String { rawValue }
}

struct ContentView: View {
    @Environment(AppServices.self) private var services
    @State private var showingSettings = false

    var body: some View {
        TabView {
            NavigationStack {
                HomeView(showingSettings: $showingSettings)
            }
            .tabItem { Label("Discover", systemImage: "sparkles.tv") }

            NavigationStack {
                SearchView(showingSettings: $showingSettings)
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }

            NavigationStack {
                WatchlistView(showingSettings: $showingSettings)
            }
            .tabItem { Label("My List", systemImage: "bookmark") }
        }
        .tint(StreamiStyle.accent)
        .task { await services.discover.load() }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .presentationDetents([.medium, .large])
        }
    }
}

private struct HomeView: View {
    @Environment(AppServices.self) private var services
    @Binding var showingSettings: Bool
    @State private var mode = DiscoverMode.forYou
    @State private var sort = CatalogSort.popular
    @State private var selectedGenreID: Int?
    @State private var selectedYear: Int?
    @State private var selectedProviderID: Int?
    @State private var trendingTimeWindow = "week"

    private var featuredTitle: TMDBTitle? {
        switch mode {
        case .forYou: services.discover.trending.first
        case .movies: services.discover.movies.first ?? services.discover.trendingMovies.first
        case .series: services.discover.shows.first ?? services.discover.trendingShows.first
        }
    }

    private var catalogType: String { mode == .series ? "tv" : "movie" }
    private var catalogTitles: [TMDBTitle] { mode == .series ? services.discover.showCatalog : services.discover.movieCatalog }
    private var availableGenres: [TMDBGenre] { mode == .series ? services.discover.showGenres : services.discover.movieGenres }
    private var availableProviders: [TMDBWatchProvider] { mode == .series ? services.discover.showProviders : services.discover.movieProviders }
    private var discoveryFilters: TMDBDiscoveryFilters {
        TMDBDiscoveryFilters(genreID: selectedGenreID, year: selectedYear, sortBy: sort.apiValue(for: catalogType), providerID: selectedProviderID)
    }
    private var catalogRequestKey: String {
        "\(mode.id)-\(selectedGenreID ?? 0)-\(selectedYear ?? 0)-\(selectedProviderID ?? 0)-\(sort.id)-\(services.preferences.regionCode)"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                if services.session.credential.isEmpty {
                    WelcomeView { showingSettings = true }
                } else {
                    if let featured = featuredTitle {
                        HeroView(title: featured)
                    } else if services.discover.isLoading {
                        VStack(spacing: 8) {
                            StreamiAnimation(size: 88)
                            Text("Finding your next favorite")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(StreamiStyle.muted)
                        }
                        .frame(maxWidth: .infinity, minHeight: 380)
                    }

                    if let error = services.discover.errorMessage {
                        ErrorNotice(message: error) { Task { await services.discover.load() } }
                    }
                }

                if !services.session.credential.isEmpty {
                    Picker("Browse", selection: $mode) {
                        ForEach(DiscoverMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)

                    switch mode {
                    case .forYou:
                        MediaShelf(title: "Trending this week", items: services.discover.trending, isLoading: services.discover.isLoading)
                        MediaShelf(title: "Trending movies", items: services.discover.trendingMovies, isLoading: services.discover.isLoading)
                        MediaShelf(title: "Trending series", items: services.discover.trendingShows, isLoading: services.discover.isLoading)
                        MediaShelf(title: "Top rated movies", items: services.discover.topRatedMovies, isLoading: services.discover.isLoading)
                        MediaShelf(title: "Now playing", items: services.discover.nowPlayingMovies, isLoading: services.discover.isLoading)
                        MediaShelf(title: "Upcoming movies", items: services.discover.upcomingMovies, isLoading: services.discover.isLoading)
                        MediaShelf(title: "Popular series", items: services.discover.shows, isLoading: services.discover.isLoading)
                        MediaShelf(title: "Top rated series", items: services.discover.topRatedShows, isLoading: services.discover.isLoading)
                        MediaShelf(title: "On the air", items: services.discover.onTheAirShows, isLoading: services.discover.isLoading)
                        MediaShelf(title: "Airing today", items: services.discover.airingTodayShows, isLoading: services.discover.isLoading)
                        let pickedForYou = services.discover.personalizedTitles(from: services.watchlist.titles)
                        if !pickedForYou.isEmpty {
                            MediaShelf(title: "Picked for you", items: pickedForYou, isLoading: false)
                        }
                    case .movies:
                        catalogGrid(title: "Movies")
                    case .series:
                        catalogGrid(title: "Series")
                    }

                    if !services.watchlist.titles.isEmpty {
                        MediaShelf(title: "My List", items: services.watchlist.titles, isLoading: false)
                    }
                }
            }
            .padding(.bottom, 30)
        }
        .background(StreamiStyle.background)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                HStack(spacing: 7) {
                    Image(systemName: "play.rectangle.fill").foregroundStyle(StreamiStyle.accent)
                    Text("streami").font(.system(size: 21, weight: .bold, design: .rounded))
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingSettings = true } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("Settings")
            }
        }
        .toolbarBackground(StreamiStyle.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationDestination(for: TMDBTitle.self) { DetailView(title: $0, services: services) }
        .task(id: catalogRequestKey) {
            guard mode == .movies || mode == .series else { return }
            await services.discover.loadCatalog(type: catalogType, filters: discoveryFilters)
        }
    }

    @ViewBuilder
    private func catalogGrid(title: String) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                Spacer()
                Menu {
                    Picker("Sort by", selection: $sort) {
                        ForEach(CatalogSort.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                } label: {
                    Label(sort.rawValue, systemImage: "arrow.up.arrow.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(StreamiStyle.muted)
                }
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Menu {
                        Button("All genres") { selectedGenreID = nil }
                        ForEach(availableGenres) { genre in
                            Button(genre.name) { selectedGenreID = genre.id }
                        }
                    } label: {
                        FilterPill(title: availableGenres.first(where: { $0.id == selectedGenreID })?.name ?? "Genre", symbol: "square.grid.2x2")
                    }

                    Menu {
                        Button("Any year") { selectedYear = nil }
                        ForEach(Array((1950...Calendar.current.component(.year, from: .now)).reversed()), id: \.self) { year in
                            Button(String(year)) { selectedYear = year }
                        }
                    } label: {
                        FilterPill(title: selectedYear.map(String.init) ?? "Year", symbol: "calendar")
                    }

                    Menu {
                        Button("Any provider") { selectedProviderID = nil }
                        ForEach(availableProviders) { provider in
                            Button(provider.providerName) { selectedProviderID = provider.providerID }
                        }
                    } label: {
                        FilterPill(
                            title: availableProviders.first(where: { $0.providerID == selectedProviderID })?.providerName ?? "Provider",
                            symbol: "tv"
                        )
                    }
                }
                .padding(.horizontal, 20)
            }

            if services.discover.isLoadingFilterOptions && availableGenres.isEmpty {
                HStack(spacing: 8) {
                    ProgressView().tint(.white)
                    Text("Loading filters")
                        .font(.caption)
                        .foregroundStyle(StreamiStyle.muted)
                }
                .padding(.horizontal, 20)
            } else if let error = services.discover.filterError {
                HStack {
                    Text("Filters unavailable: \(error)")
                        .font(.caption)
                        .foregroundStyle(StreamiStyle.muted)
                        .lineLimit(2)
                    Spacer()
                    Button("Retry") {
                        Task { await services.discover.loadFilterOptions(region: services.preferences.regionCode) }
                    }
                    .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 20)
            }

            if services.discover.isLoadingCatalog && catalogTitles.isEmpty {
                CatalogGridSkeleton()
            } else if let error = services.discover.catalogError {
                ContentUnavailableView("Couldn't load titles", systemImage: "wifi.exclamationmark", description: Text(error))
            } else if catalogTitles.isEmpty {
                CatalogEmptyState(
                    title: "No titles to show",
                    message: "Try removing one or more filters.",
                    symbol: "film",
                    actionTitle: "Clear filters"
                ) {
                    selectedGenreID = nil
                    selectedYear = nil
                    selectedProviderID = nil
                }
            } else {
                CatalogPosterGrid(titles: catalogTitles)
            }
        }
    }
}

private struct WelcomeView: View {
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            StreamiAnimation(size: 86)
            Text("Find your\nnext favorite.")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
            Text("Explore movies and series from across the world of film.")
                .font(.subheadline)
                .foregroundStyle(StreamiStyle.muted)
            Button(action: openSettings) {
                Label("Connect TMDB", systemImage: "arrow.right")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 13)
                    .background(StreamiStyle.accent, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(26)
        .frame(minHeight: 380, alignment: .bottomLeading)
        .background {
            ZStack(alignment: .topTrailing) {
                LinearGradient(colors: [StreamiStyle.surface, StreamiStyle.background], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "sparkles.tv")
                    .font(.system(size: 150, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.045))
                    .offset(x: 25, y: 28)
            }
        }
    }
}

private struct StreamiAnimation: View {
    let size: CGFloat

    var body: some View {
        LottieView(animation: .named("streami-reel"))
            .playing(loopMode: .loop)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

private struct HeroView: View {
    let title: TMDBTitle

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            KFImage(title.backdropURL)
                .placeholder {
                LinearGradient(colors: [StreamiStyle.surface, StreamiStyle.background], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            .resizable()
            .scaledToFill()
            .frame(height: 470)
            .clipped()

            LinearGradient(colors: [.clear, StreamiStyle.background.opacity(0.45), StreamiStyle.background], startPoint: .center, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 11) {
                Text("YOUR NEXT OBSESSION")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(StreamiStyle.accent)
                Text(title.displayTitle)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .lineLimit(2)
                HStack(spacing: 9) {
                    if let rating = title.voteAverage {
                        Label(rating.formatted(.number.precision(.fractionLength(1))), systemImage: "star.fill")
                            .foregroundStyle(.yellow)
                    }
                    if !title.year.isEmpty { Text(title.year) }
                    Text(title.type == "tv" ? "Series" : "Movie")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(StreamiStyle.muted)
                NavigationLink(value: title) {
                    Label("Explore title", systemImage: "arrow.up.right")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 17)
                        .padding(.vertical, 11)
                        .background(.white, in: Capsule())
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
        }
        .frame(height: 470)
        .clipped()
    }
}

private struct MediaShelf: View {
    let title: String
    let items: [TMDBTitle]
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title).font(.system(size: 19, weight: .bold, design: .rounded))
            }
            .padding(.horizontal, 20)

            if items.isEmpty && isLoading {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 13) {
                        ForEach(0..<5, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 8)
                                .fill(StreamiStyle.surface)
                                .frame(width: 132, height: 194)
                        }
                    }
                    .padding(.horizontal, 20)
                    .redacted(reason: .placeholder)
                }
            } else if items.isEmpty {
                Text("No titles found.")
                    .font(.footnote)
                    .foregroundStyle(StreamiStyle.muted)
                    .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 13) {
                        ForEach(items, id: \.listID) { item in
                            NavigationLink(value: item) {
                                PosterTile(title: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

struct PosterTile: View {
    let title: TMDBTitle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            KFImage(title.posterURL)
                .placeholder {
                Rectangle().fill(StreamiStyle.surface)
                    .overlay(Image(systemName: "film").foregroundStyle(StreamiStyle.muted))
            }
            .resizable()
            .scaledToFill()
            .frame(width: 132, height: 194)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(title.displayTitle)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .frame(width: 132, alignment: .leading)
            HStack(spacing: 5) {
                if let rating = title.voteAverage {
                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                    Text(rating.formatted(.number.precision(.fractionLength(1))))
                }
                if !title.year.isEmpty { Text("· \(title.year)") }
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(StreamiStyle.muted)
        }
        .contentShape(Rectangle())
    }
}

private struct SearchView: View {
    @Environment(AppServices.self) private var services
    @Binding var showingSettings: Bool
    @State private var query = ""
    @State private var filter = SearchFilter.all

    private var filteredResults: [TMDBTitle] {
        switch filter {
        case .all: services.search.results
        case .movies: services.search.results.filter { $0.type == "movie" }
        case .series: services.search.results.filter { $0.type == "tv" }
        }
    }

    var body: some View {
        Group {
            if services.session.credential.isEmpty {
                WelcomeView { showingSettings = true }
            } else if query.isEmpty {
                CatalogEmptyState(
                    title: "Find your next favorite",
                    message: "Search movies and series by title.",
                    symbol: "magnifyingglass"
                )
            } else if services.search.isSearching {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = services.search.errorMessage {
                ContentUnavailableView("Search unavailable", systemImage: "wifi.exclamationmark", description: Text(error))
            } else if services.search.results.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        Picker("Media type", selection: $filter) {
                            ForEach(SearchFilter.allCases) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 18)
                        .padding(.top, 12)

                        if filteredResults.isEmpty {
                            CatalogEmptyState(
                                title: "No \(filter.rawValue.lowercased()) found",
                                message: "Try another media type or search term.",
                                symbol: "film"
                            )
                        } else {
                            CatalogPosterGrid(titles: filteredResults)
                        }
                    }
                }
            }
        }
        .background(StreamiStyle.background)
        .navigationTitle("Search")
        .searchable(text: $query, prompt: "Movies, shows, people")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingSettings = true } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("Settings")
            }
        }
        .task(id: query) {
            guard !query.isEmpty else { return }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await services.search.search(query)
        }
        .navigationDestination(for: TMDBTitle.self) { DetailView(title: $0, services: services) }
    }
}

private struct WatchlistView: View {
    @Environment(AppServices.self) private var services
    @Binding var showingSettings: Bool
    @State private var showingCreateCollection = false
    @State private var showingDeleteCollection = false
    @State private var collectionName = ""

    private var activeCollection: WatchlistCollection? { services.watchlist.activeCollection }

    var body: some View {
        Group {
            if services.watchlist.activeTitles.isEmpty {
                CatalogEmptyState(
                    title: activeCollection?.name ?? "Your list is waiting",
                    message: "Add titles from any poster's collection menu.",
                    symbol: "bookmark"
                )
            } else {
                ScrollView(showsIndicators: false) {
                    CatalogPosterGrid(titles: services.watchlist.activeTitles)
                        .padding(.top, 12)
                }
            }
        }
        .background(StreamiStyle.background)
        .navigationTitle(activeCollection?.name ?? "My List")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    ForEach(services.watchlist.collections) { collection in
                        Button {
                            services.watchlist.selectCollection(collection.id)
                        } label: {
                            Label(
                                collection.name,
                                systemImage: collection.id == services.watchlist.activeCollectionID ? "checkmark.circle.fill" : "folder"
                            )
                        }
                    }
                    Button("New collection", systemImage: "plus") {
                        collectionName = ""
                        showingCreateCollection = true
                    }
                    if services.watchlist.activeCollectionID != WatchlistStore.defaultCollectionID {
                        Button("Delete collection", systemImage: "trash", role: .destructive) {
                            showingDeleteCollection = true
                        }
                    }
                } label: {
                    Image(systemName: "folder.badge.gearshape")
                }
                .accessibilityLabel("Choose or manage collections")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingSettings = true } label: { Image(systemName: "slider.horizontal.3") }
                    .accessibilityLabel("Settings")
            }
        }
        .alert("New collection", isPresented: $showingCreateCollection) {
            TextField("Collection name", text: $collectionName)
            Button("Create") { services.watchlist.createCollection(named: collectionName) }
                .disabled(collectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Collections are saved on this device.")
        }
        .confirmationDialog("Delete \(activeCollection?.name ?? "collection")?", isPresented: $showingDeleteCollection, titleVisibility: .visible) {
            Button("Delete Collection", role: .destructive) {
                services.watchlist.deleteCollection(services.watchlist.activeCollectionID)
            }
        } message: {
            Text("Titles remain in My List.")
        }
        .navigationDestination(for: TMDBTitle.self) { DetailView(title: $0, services: services) }
    }
}

private struct ErrorNotice: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(StreamiStyle.accent)
            Text(message).font(.footnote).foregroundStyle(StreamiStyle.muted)
            Spacer(minLength: 0)
            Button("Retry", action: retry).font(.footnote.weight(.semibold))
        }
        .padding(14)
        .background(StreamiStyle.surface, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 20)
    }
}

private struct FilterPill: View {
    let title: String
    let symbol: String

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.82))
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(StreamiStyle.surface, in: Capsule())
    }
}