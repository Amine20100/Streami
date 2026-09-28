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
    @State private var tab = 0
    @State private var morph = SearchMorphController()

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                HomeView(showingSettings: $showingSettings)
            }
            .tag(0)

            NavigationStack {
                SearchView(showingSettings: $showingSettings)
            }
            .tag(1)

            NavigationStack {
                WatchlistView(showingSettings: $showingSettings)
            }
            .tag(2)
        }
        .tint(DS.accent)
        .toolbar(.hidden, for: .tabBar)
        .coordinateSpace(name: "app")
        .environment(morph)
        .overlay(alignment: .bottom) {
            FloatingTabBar(selection: tab, listCount: services.watchlist.titles.count, onSelect: selectTab)
                .padding(.horizontal, 24)
                .padding(.bottom, 10)
        }
        .overlay(alignment: .topLeading) {
            SearchMorphOverlay(controller: morph)
                .allowsHitTesting(false)
        }
        .onPreferenceChange(SearchIconAnchorKey.self) { morph.iconFrame = $0 }
        .onPreferenceChange(SearchBarAnchorKey.self) { morph.barFrame = $0 }
        .task { await services.discover.load() }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .presentationDetents([.medium, .large])
        }
    }

    private func selectTab(_ index: Int) {
        if index == tab { return }
        if morph.isTransitioning { return }
        if tab == 1, morph.phase == .open {
            Task { @MainActor in await morph.close(); tab = index }
        } else if index == 1 {
            tab = index
            morph.open()
        } else {
            withAnimation(.easeInOut(duration: 0.2)) { tab = index }
        }
    }
}

private struct FloatingTabBar: View {
    let selection: Int
    let listCount: Int
    var onSelect: (Int) -> Void

    private let tabs: [(Int, String, String, String)] = [
        (0, "house", "house.fill", "Home"),
        (1, "magnifyingglass", "magnifyingglass", "Search"),
        (2, "bookmark", "bookmark.fill", "My List")
    ]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tabs, id: \.0) { tab in
                let isActive = selection == tab.0
                Button {
                    Haptics.select()
                    onSelect(tab.0)
                } label: {
                    VStack(spacing: 5) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: isActive ? tab.2 : tab.1)
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(isActive ? DS.accent : Color.white.opacity(0.55))
                                .shadow(color: isActive ? DS.accent.opacity(0.7) : .clear, radius: 8, y: 0)
                            if tab.0 == 2, listCount > 0 {
                                Text("\(min(listCount, 99))")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(DS.accent, in: Capsule())
                                    .offset(x: 12, y: -9)
                            }
                        }
                        Text(tab.3)
                            .font(.system(size: 10, weight: isActive ? .bold : .semibold))
                            .foregroundStyle(isActive ? DS.accent : Color.white.opacity(0.55))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                    .background {
                        if isActive {
                            Capsule()
                                .fill(DS.accent.opacity(0.16))
                                .overlay(
                                    Capsule()
                                        .stroke(DS.accent.opacity(0.35), lineWidth: 1)
                                )
                        }
                    }
                    .background {
                        if tab.0 == 1 {
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: SearchIconAnchorKey.self,
                                    value: geo.frame(in: .named("app"))
                                )
                            }
                        }
                    }
                }
                .buttonStyle(MicroPressStyle())
                .accessibilityLabel(tab.3)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.black.opacity(0.62))
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.7)
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(DS.accent.opacity(0.18), lineWidth: 1)
                    .blur(radius: 1)
                    .offset(y: 1)
                    .opacity(0.6)
            }
        }
        .shadow(color: .black.opacity(0.5), radius: 20, y: 8)
        .shadow(color: DS.accent.opacity(0.12), radius: 24, y: 4)
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
            VStack(alignment: .leading, spacing: 22) {
                if services.session.credential.isEmpty {
                    brandRow
                        .padding(.top, 8)
                    WelcomeView { showingSettings = true }
                } else {
                    if !heroTitles.isEmpty {
                        HeroCarousel(titles: heroTitles, showingSettings: $showingSettings)
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
                        let trending10 = Array(services.discover.trending.prefix(10))
                        MediaShelf(
                            title: "Trending Now",
                            items: trending10,
                            fullList: services.discover.trending,
                            isLoading: services.discover.isLoading
                        )
                        let personalized = services.discover.personalizedTitles(from: services.watchlist.titles)
                        let picks = personalized.isEmpty ? services.discover.topRatedMovies : personalized
                        let picks10 = Array(picks.prefix(10))
                        MediaShelf(
                            title: "Top Picks For You",
                            items: picks10,
                            fullList: picks,
                            isLoading: services.discover.isLoading && picks.isEmpty
                        )
                        Top10Shelf(
                            title: "Top 10 Today",
                            items: trending10,
                            fullList: services.discover.trending,
                            isLoading: services.discover.isLoading
                        )
                    case .movies:
                        catalogGrid(title: "Movies")
                    case .series:
                        catalogGrid(title: "Series")
                    }

                    if !services.watchlist.titles.isEmpty {
                        MediaShelf(title: "My List", items: services.watchlist.titles, fullList: services.watchlist.titles, isLoading: false)
                    }
                }
            }
            .padding(.bottom, 110)
        }
        .background(DS.background)
        .ignoresSafeArea(edges: .top)
        .refreshable { await services.discover.load() }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: TMDBTitle.self) { DetailView(title: $0, services: services) }
        .navigationDestination(for: ShelfSeeAll.self) { target in
            ShelfSeeAllView(title: target.title, items: target.items)
        }
        .task(id: catalogRequestKey) {
            guard mode == .movies || mode == .series else { return }
            await services.discover.loadCatalog(type: catalogType, filters: discoveryFilters)
        }
    }

    private var brandRow: some View {
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
            Spacer()
            Button { showingSettings = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DS.foreground)
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.08), in: Circle())
            }
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, DS.gutter)
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

// MARK: - Full-bleed cinematic hero

private struct HeroCarousel: View {
    let titles: [TMDBTitle]
    @Binding var showingSettings: Bool
    @State private var selection = 0

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .top) {
                TabView(selection: $selection) {
                    ForEach(Array(titles.enumerated()), id: \.element.listID) { index, title in
                        HeroCard(title: title)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 520)
                .clipped()
                .task {
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(6))
                        guard titles.count > 1, !UIAccessibility.isReduceMotionEnabled else { continue }
                        withAnimation(.easeInOut(duration: 0.4)) {
                            selection = (selection + 1) % titles.count
                        }
                    }
                }

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
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.6), radius: 6)
                    Spacer()
                    Button { showingSettings = true } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(.black.opacity(0.35), in: Circle())
                    }
                    .accessibilityLabel("Settings")
                }
                .padding(.horizontal, DS.gutter)
                .padding(.top, 58)
            }

            HStack(spacing: 6) {
                ForEach(titles.indices, id: \.self) { index in
                    Circle()
                        .fill(index == selection ? .white : .white.opacity(0.28))
                        .frame(width: 6, height: 6)
                        .animation(.easeInOut(duration: 0.25), value: selection)
                }
            }
            .accessibilityHidden(true)
        }
    }
}

private struct HeroCard: View {
    let title: TMDBTitle

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            KFImage(title.backdropURL)
                .placeholder {
                    LinearGradient(colors: [DS.card, DS.background], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 520)
                .clipped()

            LinearGradient(
                colors: [.black.opacity(0.45), .clear, .clear, .black.opacity(0.55), DS.background],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 10) {
                Text(title.type == "tv" ? "A STREAMI SERIES" : "A STREAMI FILM")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(3)
                    .foregroundStyle(DS.accent)
                Text(title.displayTitle.uppercased())
                    .font(.system(size: 44, weight: .black))
                    .fontWidth(.compressed)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .shadow(color: .black.opacity(0.6), radius: 10)
                HStack(spacing: 6) {
                    if let rating = title.voteAverage, rating > 0 {
                        Text(String(format: "%.1f", rating))
                            .foregroundStyle(DS.gold)
                    }
                    if !title.year.isEmpty { Text(title.year) }
                    Text(title.type == "tv" ? "Series" : "Movie")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                HStack(spacing: 12) {
                    NavigationLink(value: title) {
                        Label("Play", systemImage: "play.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(DS.accent, in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    NavigationLink(value: title) {
                        Label("More Info", systemImage: "info.circle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .overlay(Capsule().stroke(.white.opacity(0.5), lineWidth: 1.2))
                            .background(.white.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 520)
        .clipped()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title.displayTitle)
    }
}

private struct HeroSkeleton: View {
    var body: some View {
        Rectangle()
            .fill(DS.card)
            .frame(height: 520)
            .shimmer()
            .accessibilityLabel("Loading featured titles")
    }
}

// MARK: - Shelves (Netflix style)

/// Red section header with a "See All" link, like the reference design.
private struct NetflixSectionHeader: View {
    let title: String
    var target: ShelfSeeAll?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(DS.accent)
            Spacer()
            if let target {
                NavigationLink(value: target) {
                    HStack(spacing: 4) {
                        Text("See All")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(.horizontal, DS.gutter)
        .accessibilityElement(children: .combine)
    }
}

private struct MediaShelf: View {
    let title: String
    let items: [TMDBTitle]
    let fullList: [TMDBTitle]
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NetflixSectionHeader(title: title, target: items.isEmpty ? nil : ShelfSeeAll(title: title, items: fullList))

            if items.isEmpty && isLoading {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(0..<5, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 8)
                                .fill(DS.card)
                                .frame(width: 112, height: 168)
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
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(items, id: \.listID) { item in
                            NavigationLink(value: item) {
                                HomePosterCard(title: item)
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

/// Poster-only card with a red-tinted border, no captions.
private struct HomePosterCard: View {
    let title: TMDBTitle

    var body: some View {
        KFImage(title.posterURL)
            .placeholder {
                Rectangle()
                    .fill(DS.card)
                    .overlay(Image(systemName: "film").foregroundStyle(DS.muted))
            }
            .resizable()
            .scaledToFill()
            .frame(width: 112, height: 168)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(DS.accent.opacity(0.35), lineWidth: 1)
            )
            .contentShape(Rectangle())
            .accessibilityLabel(title.displayTitle)
    }
}

private struct Top10Shelf: View {
    let title: String
    let items: [TMDBTitle]
    let fullList: [TMDBTitle]
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NetflixSectionHeader(title: title, target: items.isEmpty ? nil : ShelfSeeAll(title: title, items: fullList))

            if items.isEmpty && isLoading {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(0..<5, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 8)
                                .fill(DS.card)
                                .frame(width: 150, height: 168)
                                .shimmer()
                        }
                    }
                    .padding(.horizontal, DS.gutter)
                }
                .accessibilityLabel("Loading \(title)")
            } else if !items.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(Array(items.enumerated()), id: \.element.listID) { index, item in
                            NavigationLink(value: item) {
                                HStack(alignment: .bottom, spacing: -14) {
                                    Top10Number(rank: index + 1)
                                    HomePosterCard(title: item)
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

/// Hollow red-outlined rank numeral (layered offsets behind a dark fill).
private struct Top10Number: View {
    let rank: Int
    private let f: Font = .system(size: 92, weight: .black, design: .rounded)

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                let o = [CGSize(width: 2, height: 0), CGSize(width: -2, height: 0), CGSize(width: 0, height: 2), CGSize(width: 0, height: -2), CGSize(width: 1.5, height: 1.5), CGSize(width: -1.5, height: 1.5), CGSize(width: 1.5, height: -1.5), CGSize(width: -1.5, height: -1.5)][i]
                Text("\(rank)")
                    .font(f)
                    .foregroundStyle(DS.accent)
                    .offset(o)
            }
            Text("\(rank)")
                .font(f)
                .foregroundStyle(Color(red: 0.08, green: 0.02, blue: 0.03))
        }
        .frame(width: 64)
        .offset(y: 8)
        .accessibilityHidden(true)
    }
}

struct ShelfSeeAll: Hashable {
    let title: String
    let items: [TMDBTitle]
}

private struct ShelfSeeAllView: View {
    @Environment(AppServices.self) private var services
    let title: String
    let items: [TMDBTitle]

    var body: some View {
        ScrollView(showsIndicators: false) {
            CatalogPosterGrid(titles: items)
                .padding(.top, 12)
                .padding(.bottom, 110)
        }
        .background(DS.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(DS.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationDestination(for: TMDBTitle.self) { DetailView(title: $0, services: services) }
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

// MARK: - Search + Watchlist

private struct SearchView: View {
    @Environment(AppServices.self) private var services
    @Environment(SearchMorphController.self) private var morph
    @Binding var showingSettings: Bool
    @State private var query = ""
    @State private var selectedGenreID: Int? = nil

    private var allGenres: [TMDBGenre] {
        var seen = Set<Int>()
        var ordered: [TMDBGenre] = []
        for genre in services.discover.movieGenres + services.discover.showGenres
            where seen.insert(genre.id).inserted {
            ordered.append(genre)
        }
        return ordered.sorted { $0.name < $1.name }
    }

    private var orderedGenres: [TMDBGenre] {
        let featuredOrder = ["Action", "Comedy", "Science Fiction", "Thriller", "Documentary"]
        let byName = Dictionary(uniqueKeysWithValues: allGenres.map { ($0.name, $0) })
        var featured: [TMDBGenre] = []
        for name in featuredOrder {
            if let genre = byName[name] { featured.append(genre) }
        }
        let featuredIDs = Set(featured.map(\.id))
        let rest = allGenres.filter { !featuredIDs.contains($0.id) }
        return featured + rest
    }

    private func displayName(for genre: TMDBGenre) -> String {
        genre.name == "Science Fiction" ? "Sci-Fi" : genre.name
    }

    private func matchesGenre(_ title: TMDBTitle) -> Bool {
        guard let id = selectedGenreID else { return true }
        return title.genreIDs?.contains(id) ?? false
    }

    private var browseTitles: [TMDBTitle] {
        var seen = Set<String>()
        var ordered: [TMDBTitle] = []
        for title in services.discover.trending + services.discover.movies + services.discover.shows
            where seen.insert(title.listID).inserted {
            ordered.append(title)
        }
        return ordered.filter(matchesGenre)
    }

    private var filteredResults: [TMDBTitle] {
        services.search.results.filter(matchesGenre)
    }

    var body: some View {
        Group {
            if services.session.credential.isEmpty {
                WelcomeView { showingSettings = true }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        searchBar
                        genreChips
                            .searchReveal(morph)
                        Group {
                            if query.isEmpty {
                                if services.discover.isLoading && browseTitles.isEmpty {
                                    SearchGridSkeleton()
                                } else if browseTitles.isEmpty {
                                    CatalogEmptyState(
                                        title: "Nothing to browse",
                                        message: "Pull down to refresh or try again later.",
                                        symbol: "film"
                                    )
                                } else {
                                    SearchPosterGrid(titles: browseTitles)
                                }
                            } else if services.search.isSearching {
                                SearchGridSkeleton()
                            } else if let error = services.search.errorMessage {
                                ContentUnavailableView("Search unavailable", systemImage: "wifi.exclamationmark", description: Text(error))
                            } else if filteredResults.isEmpty {
                                ContentUnavailableView.search(text: query)
                            } else {
                                SearchPosterGrid(titles: filteredResults)
                            }
                        }
                        .searchReveal(morph)
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 110)
                }
                .refreshable { await services.discover.load() }
            }
        }
        .background(DS.background)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingSettings = true } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("Settings")
            }
        }
        .toolbarBackground(DS.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onDisappear {
            if morph.phase == .open { morph.animateEntrance = false }
        }
        .task(id: query) {
            guard !query.isEmpty else { return }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await services.search.search(query)
        }
        .task(id: allGenres.map(\.id)) {
            if selectedGenreID == nil,
               let action = allGenres.first(where: { $0.name == "Action" }) {
                selectedGenreID = action.id
            }
        }
        .navigationDestination(for: TMDBTitle.self) { DetailView(title: $0, services: services) }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.7))
            TextField("Search movies, shows, genres...", text: $query)
                .foregroundStyle(.white)
                .tint(DS.accent)
                .submitLabel(.search)
                .font(.system(size: 15))
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(Color(red: 0.11, green: 0.11, blue: 0.13), in: Capsule())
        .overlay(Capsule().stroke(DS.accent.opacity(0.55), lineWidth: 1))
        .shadow(color: DS.accent.opacity(0.25), radius: 14, y: 0)
        .background {
            GeometryReader { geo in
                Color.clear.preference(
                    key: SearchBarAnchorKey.self,
                    value: geo.frame(in: .named("app"))
                )
            }
        }
        .opacity(morph.animateEntrance && morph.phase != .open ? (morph.expand >= 1 ? 1 : 0) : 1)
        .scaleEffect(morph.animateEntrance && morph.phase != .open ? 0.96 : 1)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Search movies, shows, genres")
    }

    private var genreChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(orderedGenres) { genre in
                    let isActive = selectedGenreID == genre.id
                    Button {
                        Haptics.select()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedGenreID = isActive ? nil : genre.id
                        }
                    } label: {
                        Text(displayName(for: genre))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isActive ? .white : .white.opacity(0.72))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(isActive ? DS.accent : Color.white.opacity(0.07), in: Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(isActive ? Color.clear : .white.opacity(0.13), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Filter by \(displayName(for: genre))")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
        }
    }
}

private struct SearchPosterGrid: View {
    @Environment(AppServices.self) private var services
    let titles: [TMDBTitle]

    private let columns: [GridItem] = [
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 12),
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 12),
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(titles, id: \.listID) { title in
                NavigationLink(value: title) {
                    SearchPosterCard(title: title)
                }
                .buttonStyle(PressableStyle())
                .contextMenu {
                    ForEach(services.watchlist.collections) { collection in
                        let isMember = services.watchlist.contains(title, in: collection.id)
                        Button {
                            services.watchlist.setMembership(title, in: collection.id, isMember: !isMember)
                        } label: {
                            Label(
                                "\(isMember ? "Remove from" : "Add to") \(collection.name)",
                                systemImage: isMember ? "checkmark.circle" : "folder.badge.plus"
                            )
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

private struct SearchPosterCard: View {
    let title: TMDBTitle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            KFImage(title.posterURL)
                .placeholder {
                    Rectangle()
                        .fill(Color(red: 0.13, green: 0.13, blue: 0.16))
                        .overlay {
                            Image(systemName: "film")
                                .font(.title3)
                                .foregroundStyle(Color.white.opacity(0.3))
                        }
                }
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity)
                .aspectRatio(2 / 3, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )
                .clipped()

            Text(title.displayTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title.displayTitle)
    }
}

private struct SearchGridSkeleton: View {
    private let columns: [GridItem] = [
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 12),
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 12),
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(0..<9, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.08))
                        .aspectRatio(2 / 3, contentMode: .fit)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 12)
                        .padding(.trailing, 16)
                }
                .shimmer()
            }
        }
        .padding(.horizontal, 16)
        .accessibilityLabel("Loading titles")
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
                    .padding(.bottom, 100)
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
