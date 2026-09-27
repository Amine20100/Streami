import SwiftUI
import Kingfisher

struct DetailView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.openURL) private var openURL
    let title: TMDBTitle
    @StateObject private var model: DetailViewModel
    @State private var selectedSeason: Int? = nil
    @State private var selectedEpisode: Int? = nil
    @State private var showSeasonPicker = false
    @State private var showEpisodePicker = false
    @State private var seasonEpisodes: [TMDBEpisode] = []
    @State private var isLoadingEpisodes = false
    @State private var pendingSource: StreamingSource?
    @State private var selectedSourceID: String? = nil
    @State private var showPlayer = false
    @State private var playerSource: StreamingSource?
    @State private var playerSeason: Int?
    @State private var playerEpisode: Int?
    @State private var triedSourceIDs: Set<String> = []
    @State private var showPlayerError = false
    @State private var showCastSheet = false
    @State private var showRecsSheet = false

    init(title: TMDBTitle, services: AppServices) {
        self.title = title
        _model = StateObject(wrappedValue: DetailViewModel(
            title: title,
            session: services.session,
            preferences: services.preferences,
            watchlist: services.watchlist
        ))
    }

    private var titleWithIMDB: TMDBTitle {
        guard let imdbID = model.imdbID else { return title }
        var enriched = title
        enriched.imdbID = imdbID
        return enriched
    }

    private var mediaType: String { title.type == "movie" ? "movie" : "tv" }

    private func play(_ source: StreamingSource, season: Int?, episode: Int?) {
        triedSourceIDs = [source.id]
        playerSource = source
        playerSeason = season
        playerEpisode = episode
        showPlayerError = false
        showPlayer = true
    }

    private func effectiveSource() -> StreamingSource? {
        if let id = selectedSourceID,
           let chosen = services.streamingSources.sources.first(where: { $0.id == id }),
           chosen.isEnabled {
            return chosen
        }
        return services.streamingSources.getBestSource(for: mediaType)
    }

    private func playEffective() {
        Haptics.tap()
        guard let source = effectiveSource() else { return }
        if title.type == "movie" {
            play(source, season: nil, episode: nil)
        } else if let season = selectedSeason, let episode = selectedEpisode {
            play(source, season: season, episode: episode)
        } else {
            pendingSource = source
            showSeasonPicker = true
        }
    }

    private func advanceToNextSource() {
        let candidates = services.streamingSources.enabledSources(for: mediaType)
            .filter { !triedSourceIDs.contains($0.id) }
        if let next = candidates.first {
            triedSourceIDs.insert(next.id)
            playerSource = next
        } else {
            showPlayer = false
            showPlayerError = true
        }
    }

    private var hasProgress: Bool {
        services.streamingSources.getProgress(for: title) != nil
    }

    private var enabledSources: [StreamingSource] {
        services.streamingSources.enabledSources(for: mediaType)
    }

    private var activeSourceID: String? {
        selectedSourceID ?? services.streamingSources.getBestSource(for: mediaType)?.id
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                heroSection
                metaRow
                actionRow
                serverPills
                overviewSection
                castSection
                recsSection
                reviewsSection
                Text("Streami is a discovery guide. Streaming sources are third-party and may not be available in all regions.")
                    .font(.caption)
                    .foregroundStyle(DS.muted)
                    .padding(.horizontal, DS.gutter)
                    .padding(.bottom, 24)
            }
        }
        .background(DS.background)
        .ignoresSafeArea(edges: .top)
        .navigationTitle(title.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(DS.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task(id: "\(title.type)-\(title.id)-\(model.regionCode)") { await model.loadSupportingData() }
        .sheet(isPresented: $showSeasonPicker) {
            SeasonPickerSheet(
                seasons: model.seasons,
                onSelect: { season in
                    selectedSeason = season
                    selectedEpisode = nil
                    showSeasonPicker = false
                    Task {
                        isLoadingEpisodes = true
                        seasonEpisodes = await model.seasonEpisodes(season: season)
                        isLoadingEpisodes = false
                        if seasonEpisodes.isEmpty {
                            if let fallback = pendingSource ?? services.streamingSources.getBestSource(for: "tv") {
                                play(fallback, season: season, episode: 1)
                            }
                        } else {
                            showEpisodePicker = true
                        }
                    }
                }
            )
        }
        .sheet(isPresented: $showEpisodePicker) {
            EpisodePickerSheet(
                season: selectedSeason ?? 1,
                episodes: seasonEpisodes,
                isLoading: isLoadingEpisodes,
                onSelect: { episode in
                    selectedEpisode = episode
                    showEpisodePicker = false
                    if let source = pendingSource ?? services.streamingSources.getBestSource(for: mediaType) {
                        play(source, season: selectedSeason, episode: episode)
                    }
                    pendingSource = nil
                }
            )
        }
        .sheet(isPresented: $showCastSheet) {
            NavigationStack {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                        ForEach(model.details?.cast ?? []) { member in
                            CastCell(member: member)
                        }
                    }
                    .padding(20)
                }
                .background(DS.background)
                .navigationTitle("Cast")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(DS.background, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showRecsSheet) {
            NavigationStack {
                ScrollView(showsIndicators: false) {
                    CatalogPosterGrid(titles: model.recommendations)
                        .padding(.top, 12)
                }
                .background(DS.background)
                .navigationTitle("More Like This")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(DS.background, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
            }
            .presentationDetents([.medium, .large])
        }
        .alert("Playback failed", isPresented: $showPlayerError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("None of the enabled sources could play this title. Try another source in Settings.")
        }
        .fullScreenCover(isPresented: $showPlayer) {
            if let source = playerSource {
                StreamingPlayerView(
                    title: titleWithIMDB,
                    source: source,
                    season: playerSeason,
                    episode: playerEpisode,
                    onSourceFailed: {
                        advanceToNextSource()
                    }
                )
            }
        }
        .onAppear {
            setupNotificationObservers()
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self)
        }
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(forName: .playNextEpisode, object: nil, queue: .main) { [self] notification in
            if let nextEpisode = notification.userInfo?["nextEpisode"] as? Int,
               let season = notification.userInfo?["season"] as? Int,
               let sourceID = notification.userInfo?["sourceID"] as? String,
               let source = services.streamingSources.sources.first(where: { $0.id == sourceID }) {
                playerSource = source
                playerSeason = season
                playerEpisode = nextEpisode
                showPlayer = true
            }
        }
    }

    // MARK: - Sections

    private var heroSection: some View {
        KFImage(title.backdropURL)
            .placeholder {
                LinearGradient(colors: [DS.card, DS.background], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            .resizable()
            .scaledToFill()
            .frame(height: 400)
            .clipped()
            .overlay {
                LinearGradient(colors: [.clear, DS.background.opacity(0.55), DS.background], startPoint: .center, endPoint: .bottom)
            }
            .accessibilityLabel("\(title.displayTitle) backdrop")
    }

    private var metaRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.displayTitle)
                .font(DS.display(26))
                .foregroundStyle(.white)
                .lineLimit(3)
            HStack(spacing: 10) {
                if !title.year.isEmpty {
                    Text(title.year)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(DS.foreground.opacity(0.9))
                }
                if let runtime = model.displayRuntime {
                    Text(runtime)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(DS.foreground.opacity(0.9))
                }
                if let certification = model.certification {
                    Text(certification)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DS.foreground)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.white.opacity(0.55), lineWidth: 1)
                        )
                }
                Text("HD")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(DS.foreground)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(.horizontal, DS.gutter)
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button(action: playEffective) {
                Label(hasProgress ? "Resume" : "Play", systemImage: "play.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(DS.accent, in: Capsule())
            }
            .buttonStyle(PressableStyle())
            .accessibilityHint("Starts playback with the selected source")

            Button {
                Haptics.tap()
                model.toggleSaved()
            } label: {
                Label(model.isSaved ? "Saved" : "My List", systemImage: model.isSaved ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.35), lineWidth: 1)
                    )
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(model.isSaved ? "Remove from My List" : "Add to My List")
        }
        .padding(.horizontal, DS.gutter)
    }

    private var serverPills: some View {
        Group {
            if !enabledSources.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(enabledSources.enumerated()), id: \.element.id) { index, source in
                            let isActive = activeSourceID == source.id
                            Button {
                                Haptics.select()
                                selectedSourceID = source.id
                                if title.type == "tv" && (selectedSeason == nil || selectedEpisode == nil) {
                                    pendingSource = source
                                    showSeasonPicker = true
                                }
                            } label: {
                                Text("Server \(index + 1) - \(source.name)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 12)
                                    .background(
                                        isActive ? DS.accent : Color.clear,
                                        in: Capsule()
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(isActive ? Color.clear : .white.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(PressableStyle())
                            .accessibilityLabel("Use \(source.name)")
                        }
                    }
                    .padding(.horizontal, DS.gutter)
                }
            }
        }
    }

    private var overviewSection: some View {
        Group {
            if let overview = title.overview, !overview.isEmpty {
                Text(overview)
                    .font(.system(size: 15))
                    .lineSpacing(4)
                    .foregroundStyle(DS.foreground.opacity(0.88))
                    .padding(.horizontal, DS.gutter)
            }
        }
    }

    private var castSection: some View {
        Group {
            if let cast = model.details?.cast, !cast.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Cast")
                            .font(DS.headline(21))
                            .foregroundStyle(.white)
                        Spacer()
                        Button {
                            Haptics.tap()
                            showCastSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Text("See All")
                                Image(systemName: "chevron.right")
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(DS.muted)
                        }
                        .buttonStyle(PressableStyle())
                    }
                    .padding(.horizontal, DS.gutter)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(cast) { member in
                                CastCell(member: member)
                            }
                        }
                        .padding(.horizontal, DS.gutter)
                    }
                }
            }
        }
    }

    private var recsSection: some View {
        Group {
            if !model.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("More Like This")
                            .font(DS.headline(21))
                            .foregroundStyle(.white)
                        Spacer()
                        Button {
                            Haptics.tap()
                            showRecsSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Text("See All")
                                Image(systemName: "chevron.right")
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(DS.muted)
                        }
                        .buttonStyle(PressableStyle())
                    }
                    .padding(.horizontal, DS.gutter)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 13) {
                            ForEach(model.recommendations, id: \.listID) { recommendation in
                                NavigationLink(value: recommendation) {
                                    PosterTile(title: recommendation)
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

    private var reviewsSection: some View {
        Group {
            if let reviews = model.reviews, !reviews.results.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Reviews")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 13) {
                            ForEach(reviews.results.prefix(5)) { review in
                                ReviewCard(review: review)
                            }
                        }
                        .padding(.horizontal, DS.gutter)
                    }
                }
            }
        }
    }
}

// MARK: - Cast cell

private struct CastCell: View {
    let member: TMDBCastMember

    var body: some View {
        VStack(spacing: 8) {
            KFImage(member.profileURL)
                .placeholder {
                    Circle()
                        .fill(DS.card)
                        .overlay(Image(systemName: "person.fill").foregroundStyle(DS.muted))
                }
                .resizable()
                .scaledToFill()
                .frame(width: 84, height: 84)
                .clipShape(Circle())
                .overlay(Circle().stroke(DS.accent, lineWidth: 2))
            Text(member.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.foreground)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 84)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(member.name), \(member.creditDescription)")
    }
}

// MARK: - Season Picker Sheet

struct SeasonPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let seasons: [TMDBSeason]
    let onSelect: (Int) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Select Season") {
                    ForEach(seasons) { season in
                        Button {
                            if let number = season.seasonNumber {
                                onSelect(number)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                KFImage(season.posterURL)
                                    .placeholder {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(.white.opacity(0.12))
                                            .overlay(Image(systemName: "tv").foregroundStyle(.secondary))
                                    }
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 44, height: 66)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(season.name ?? "Season \(season.seasonNumber ?? 0)")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.primary)
                                    Text("\(season.episodeCount ?? 0) episodes")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Season")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Episode Picker Sheet

struct EpisodePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let season: Int
    let episodes: [TMDBEpisode]
    let isLoading: Bool
    let onSelect: (Int) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading episodes...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if episodes.isEmpty {
                    ContentUnavailableView("No episodes found", systemImage: "tv", description: Text("Episode data is unavailable for this season."))
                } else {
                    List {
                        Section("Season \(season) - Select Episode") {
                            ForEach(episodes) { episode in
                                Button {
                                    if let number = episode.episodeNumber {
                                        onSelect(number)
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        KFImage(episode.stillURL)
                                            .placeholder {
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(.white.opacity(0.12))
                                                    .overlay(Image(systemName: "play.fill").foregroundStyle(.secondary))
                                            }
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 88, height: 50)
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("E\(episode.episodeNumber ?? 0) - \(episode.name ?? "Episode")")
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundStyle(.primary)
                                                .lineLimit(2)
                                            if let overview = episode.overview, !overview.isEmpty {
                                                Text(overview)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(2)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Episode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Review Card

struct ReviewCard: View {
    let review: TMDBReview

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                let author = review.authorDetails?.name ?? review.author
                Text(author)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.foreground)
                Spacer()
                if let rating = review.authorDetails?.rating {
                    Text(String(format: "%.1f/10", rating))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DS.gold)
                }
            }

            Text(review.content)
                .font(.caption)
                .foregroundStyle(DS.foreground.opacity(0.7))
                .lineLimit(4)

            Text(review.createdAt.prefix(10))
                .font(.caption2)
                .foregroundStyle(DS.muted)
        }
        .padding(14)
        .frame(width: 280)
        .background(DS.card, in: RoundedRectangle(cornerRadius: DS.radiusMedium))
    }
}

// MARK: - Provider Group

private struct ProviderGroup: View {
    let title: String
    let providers: [TMDBWatchProvider]

    var body: some View {
        if !providers.isEmpty {
            VStack(alignment: .leading, spacing: 9) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.muted)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(providers) { provider in
                            HStack(spacing: 8) {
                                KFImage(provider.logoURL)
                                    .placeholder {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(.white.opacity(0.12))
                                            .overlay(Text(String(provider.providerName.prefix(1))).font(.caption.bold()))
                                    }
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 34, height: 34)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                Text(provider.providerName)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                            }
                            .padding(7)
                            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: DS.radiusSmall))
                        }
                    }
                }
            }
        }
    }
}
