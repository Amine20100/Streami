import SwiftUI
import Kingfisher
import Lottie
import Charts

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
            .badge(services.watchlist.titles.count)
        }
        .tint(DS.accent)
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

    private var heroTitles: [TMDBTitle] {
        let pool: [TMDBTitle]
        switch mode {
        case .forYou: pool = services.discover.trending
        case .movies: pool = services.discover.movies + services.discover.trendingMovies
        case .series: pool = services.discover.shows + services.discover.trendingShows
        }
        return Array(pool.prefix(5))
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
            VStack(alignment: .leading, spacing: 26) {
                if services.session.credential.isEmpty {
                    WelcomeView { showingSettings = true }
                } else {
                    if !heroTitles.isEmpty {
                        HeroCarousel(titles: heroTitles)
                    } else if services.discover.isLoading {
                        HeroSkeleton()
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
                    .padding(.horizontal, DS.gutter)
                    .sensoryFeedback(.selection, trigger: mode)

                    switch mode {
                    case .forYou:
                        MediaShelf(title: "Trending now", subtitle: "What everyone is watching", items: services.discover.trending, isLoading: services.discover.isLoading, ranked: true)
                        MediaShelf(title: "Trending movies", items: services.discover.trendingMovies, isLoading: services.discover.isLoading)
                        MediaShelf(title: "Trending series", items: services.discover.trendingShows, isLoading: services.discover.isLoading)
                        MediaShelf(title: "Top rated movies", items: services.discover.topRatedMovies, isLoading: services.discover.isLoading)
                        MediaShelf(title: "Now playing", items: services.discover.nowPlayingMovies, isLoading: services.discover.isLoading)
                        MediaShelf(title: "Coming soon", items: services.discover.upcomingMovies, isLoading: services.discover.isLoading)
                        MediaShelf(title: "Popular series", items: services.discover.shows, isLoading: services.discover.isLoading)
                        MediaShelf(title: "Top rated series", items: services.discover.topRatedShows, isLoading: services.discover.isLoading)
                        let pickedForYou = services.discover.personalizedTitles(from: services.watchlist.titles)
                        if !pickedForYou.isEmpty {
                            MediaShelf(title: "Picked for you", subtitle: "Based on your list", items: pickedForYou, isLoading: false)
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
        .background(DS.background)
        .refreshable { await services.discover.load() }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(DS.accent)
                            .frame(width: 26, height: 26)
                        Image(systemName: "play.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Text("streami")
                        .font(DS.display(21))
                        .foregroundStyle(DS.foreground)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingSettings = true } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DS.foreground)
                        .frame(width: 38, height: 38)
                        .background(.white.opacity(0.08), in: Circle())
                }
                .accessibilityLabel("Settings")
            }
        }
        .toolbarBackground(DS.background, for: .navigationBar)
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
                    .font(DS.display(23))
                    .foregroundStyle(DS.foreground)
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
                        .foregroundStyle(DS.muted)
                }
            }
            .padding(.horizontal, DS.gutter)

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
                            Button(provider.providerName) { selectedProviderID = provider.id }
                        }
                    } label: {
                        FilterPill(
                            title: availableProviders.first(where: { $0.id == selectedProviderID })?.providerName ?? "Provider",
                            symbol: "tv"
                        )
                    }
                }
                .padding(.horizontal, DS.gutter)
            }

            if services.discover.isLoadingFilterOptions && availableGenres.isEmpty {
                HStack(spacing: 8) {
                    ProgressView().tint(.white)
                    Text("Loading filters")
                        .font(.caption)
                        .foregroundStyle(DS.muted)
                }
                .padding(.horizontal, DS.gutter)
            } else if let error = services.discover.filterError {
                HStack {
                    Text("Filters unavailable: \(error)")
                        .font(.caption)
                        .foregroundStyle(DS.muted)
                        .lineLimit(2)
                    Spacer()
                    Button("Retry") {
                        Task { await services.discover.loadFilterOptions(region: services.preferences.regionCode) }
                    }
                    .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, DS.gutter)
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
                .font(DS.display(38))
                .foregroundStyle(DS.foreground)
                .fixedSize(horizontal: false, vertical: true)
            Text("Movies and series from across the world of film — trailers, ratings, and where to watch.")
                .font(.subheadline)
                .foregroundStyle(DS.muted)
            Button(action: {
                Haptics.tap()
                openSettings()
            }) {
                Label("Connect TMDB", systemImage: "arrow.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(DS.accent, in: Capsule())
            }
            .buttonStyle(PressableStyle())
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(26)
        .frame(minHeight: 400, alignment: .bottomLeading)
        .background {
            ZStack(alignment: .topTrailing) {
                LinearGradient(colors: [DS.secondary.opacity(0.55), DS.background], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "sparkles.tv")
                    .font(.system(size: 150, weight: .ultraLight))
                    .foregroundStyle(DS.accent.opacity(0.16))
                    .offset(x: 25, y: 28)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.radiusLarge))
        .padding(.horizontal, DS.gutter)
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

// MARK: - Paging hero carousel

private struct HeroCarousel: View {
    let titles: [TMDBTitle]
    @State private var selection = 0

    var body: some View {
        VStack(spacing: 10) {
            TabView(selection: $selection) {
                ForEach(Array(titles.enumerated()), id: \.element.listID) { index, title in
                    HeroCard(title: title, rank: index + 1)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 480)
            .clipShape(RoundedRectangle(cornerRadius: DS.radiusLarge))
            .padding(.horizontal, DS.gutter)
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(6))
                    guard titles.count > 1, !UIAccessibility.isReduceMotionEnabled else { continue }
                    withAnimation(.easeInOut(duration: 0.4)) {
                        selection = (selection + 1) % titles.count
                    }
                }
            }

            HStack(spacing: 6) {
                ForEach(titles.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == selection ? DS.accent : .white.opacity(0.22))
                        .frame(width: index == selection ? 22 : 6, height: 6)
                        .animation(.easeInOut(duration: 0.25), value: selection)
                }
            }
            .accessibilityHidden(true)
        }
    }
}

private struct HeroCard: View {
    @Environment(AppServices.self) private var services
    let title: TMDBTitle
    let rank: Int

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            KFImage(title.backdropURL)
                .placeholder {
                    LinearGradient(colors: [DS.card, DS.background], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
                .resizable()
                .scaledToFill()
                .frame(height: 480)
                .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.35), .black.opacity(0.92)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("TRENDING #\(rank)")
                        .font(DS.eyebrow)
                        .tracking(1.5)
                        .foregroundStyle(DS.accent)
                    if let rating = title.voteAverage {
                        RatingBadge(rating: rating)
                    }
                }
                Text(title.displayTitle)
                    .font(DS.display(32))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    if !title.year.isEmpty { MetaPill(text: title.year) }
                    MetaPill(text: title.type == "tv" ? "Series" : "Movie", systemImage: title.type == "tv" ? "tv" : "film")
                }
                HStack(spacing: 10) {
                    NavigationLink(value: title) {
                        Label("Watch now", systemImage: "play.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(DS.accent, in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    Button {
                        Haptics.tap()
                        services.watchlist.toggle(title)
                    } label: {
                        Image(systemName: services.watchlist.contains(title) ? "checkmark" : "plus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.16), in: Circle())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(services.watchlist.contains(title) ? "In My List" : "Add to My List")
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 26)
        }
        .frame(height: 480)
        .clipped()
    }
}

private struct HeroSkeleton: View {
    var body: some View {
        RoundedRectangle(cornerRadius: DS.radiusLarge)
            .fill(DS.card)
            .frame(height: 480)
            .padding(.horizontal, DS.gutter)
            .shimmer()
            .accessibilityLabel("Loading featured titles")
    }
}

// MARK: - Shelves

private struct MediaShelf: View {
    let title: String
    var subtitle: String?
    let items: [TMDBTitle]
    let isLoading: Bool
    var ranked: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: title, subtitle: subtitle)

            if items.isEmpty && isLoading {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 13) {
                        ForEach(0..<5, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: DS.radiusSmall)
                                .fill(DS.card)
                                .frame(width: DS.posterW, height: DS.posterH)
                                .shimmer()
                        }
                    }
                    .padding(.horizontal, DS.gutter)
                }
                .accessibilityLabel("Loading \(title)")
            } else if items.isEmpty {
                Text("No titles found.")
                    .font(.footnote)
                    .foregroundStyle(DS.muted)
                    .padding(.horizontal, DS.gutter)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 13) {
                        ForEach(Array(items.enumerated()), id: \.element.listID) { index, item in
                            NavigationLink(value: item) {
                                if ranked {
                                    RankedPosterTile(title: item, rank: index + 1)
                                } else {
                                    PosterTile(title: item)
                                }
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                    .padding(.horizontal, DS.gutter)
                }
            }
        }
    }
}

struct PosterTile: View {
    let title: TMDBTitle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                KFImage(title.posterURL)
                    .placeholder {
                        Rectangle().fill(DS.card)
                            .overlay(Image(systemName: "film").foregroundStyle(DS.muted))
                    }
                    .resizable()
                    .scaledToFill()
                    .frame(width: DS.posterW, height: DS.posterH)
                    .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
                if let rating = title.voteAverage {
                    RatingBadge(rating: rating)
                        .padding(7)
                }
            }
            Text(title.displayTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.foreground)
                .lineLimit(1)
                .frame(width: DS.posterW, alignment: .leading)
            HStack(spacing: 5) {
                Text(title.type == "tv" ? "Series" : "Movie")
                if !title.year.isEmpty { Text("· \(title.year)") }
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(DS.muted)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title.displayTitle), \(title.type == "tv" ? "series" : "movie")")
    }
}

private struct RankedPosterTile: View {
    let title: TMDBTitle
    let rank: Int

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Text("\(rank)")
                .font(.system(size: 72, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .shadow(color: DS.accent.opacity(0.45), radius: 12)
                .frame(width: 56)
                .offset(y: 6)
            PosterTile(title: title)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Search + Watchlist

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
                CatalogGridSkeleton()
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
        .background(DS.background)
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
                    VStack(alignment: .leading, spacing: 20) {
                        WatchStatsCard(titles: services.watchlist.activeTitles)
                            .padding(.horizontal, 18)
                        CatalogPosterGrid(titles: services.watchlist.activeTitles)
                    }
                    .padding(.top, 12)
                }
            }
        }
        .background(DS.background)
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

private struct WatchStatsCard: View {
    let titles: [TMDBTitle]

    private var ratings: [Double] {
        titles.compactMap(\.voteAverage).filter { $0 > 0 }
    }

    private var buckets: [(label: String, count: Int)] {
        let groups = ["< 6", "6–7", "7–8", "8+"]
        var counts = [0, 0, 0, 0]
        for rating in ratings {
            switch rating {
            case ..<6: counts[0] += 1
            case ..<7: counts[1] += 1
            case ..<8: counts[2] += 1
            default: counts[3] += 1
            }
        }
        return zip(groups, counts).map { ($0, $1) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your list at a glance")
                .font(DS.headline(15))
                .foregroundStyle(DS.foreground)
            HStack(spacing: 20) {
                StatBlock(value: "\(titles.filter { $0.type == "movie" }.count)", label: "Movies")
                StatBlock(value: "\(titles.filter { $0.type == "tv" }.count)", label: "Series")
                if !ratings.isEmpty {
                    StatBlock(
                        value: (ratings.reduce(0, +) / Double(ratings.count)).formatted(.number.precision(.fractionLength(1))),
                        label: "Avg rating"
                    )
                }
            }
            if !ratings.isEmpty {
                Chart(buckets, id: \.label) { bucket in
                    BarMark(
                        x: .value("Rating", bucket.label),
                        y: .value("Titles", bucket.count)
                    )
                    .foregroundStyle(DS.accent.gradient)
                    .cornerRadius(4)
                }
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel()
                            .font(.caption2)
                            .foregroundStyle(DS.muted)
                    }
                }
                .frame(height: 110)
                .accessibilityLabel("Rating distribution of your list")
            }
        }
        .padding(16)
        .background(DS.card, in: RoundedRectangle(cornerRadius: DS.radiusMedium))
    }
}

private struct StatBlock: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(DS.display(24))
                .foregroundStyle(DS.foreground)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(DS.muted)
        }
    }
}

// MARK: - Shared bits

private struct ErrorNotice: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(DS.accent)
            Text(message).font(.footnote).foregroundStyle(DS.muted)
            Spacer(minLength: 0)
            Button("Retry", action: retry).font(.footnote.weight(.semibold))
        }
        .padding(14)
        .background(DS.card, in: RoundedRectangle(cornerRadius: DS.radiusSmall))
        .padding(.horizontal, DS.gutter)
    }
}

private struct FilterPill: View {
    let title: String
    let symbol: String

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(DS.foreground.opacity(0.85))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.white.opacity(0.08), in: Capsule())
    }
}
