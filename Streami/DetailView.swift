import SwiftUI
import Kingfisher
import WebKit

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
    @State private var showPlayer = false
    @State private var playerSource: StreamingSource?
    @State private var playerSeason: Int?
    @State private var playerEpisode: Int?
    @State private var triedSourceIDs: Set<String> = []
    @State private var showPlayerError = false

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

    private func play(_ source: StreamingSource, season: Int?, episode: Int?) {
        triedSourceIDs = [source.id]
        playerSource = source
        playerSeason = season
        playerEpisode = episode
        showPlayerError = false
        showPlayer = true
    }

    private func advanceToNextSource() {
        let type = title.type == "movie" ? "movie" : "tv"
        let candidates = services.streamingSources.enabledSources(for: type)
            .filter { !triedSourceIDs.contains($0.id) }
        if let next = candidates.first {
            triedSourceIDs.insert(next.id)
            playerSource = next
        } else {
            showPlayer = false
            showPlayerError = true
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // Backdrop with title overlay
                ZStack(alignment: .bottomLeading) {
                    KFImage(title.backdropURL)
                        .placeholder {
                        Rectangle().fill(Color(red: 0.09, green: 0.105, blue: 0.125))
                    }
                    .resizable()
                    .scaledToFill()
                    .frame(height: 280)
                    .clipped()
                    LinearGradient(colors: [.clear, Color(red: 0.035, green: 0.045, blue: 0.06)], startPoint: .center, endPoint: .bottom)
                }
                .overlay(alignment: .bottomLeading) {
                    Text(title.displayTitle)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                }

                // Metadata
                HStack(spacing: 14) {
                    if !title.year.isEmpty { Text(title.year) }
                    Text(title.type == "tv" ? "Series" : "Movie")
                    if let rating = title.voteAverage {
                        Label(rating.formatted(.number.precision(.fractionLength(1))), systemImage: "star.fill")
                            .foregroundStyle(.yellow)
                    }
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 20)

                // Overview
                if let overview = title.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.body)
                        .lineSpacing(5)
                        .foregroundStyle(.white.opacity(0.82))
                        .padding(.horizontal, 20)
                }

                // Continue Watching (if there's progress)
                if let progress = services.streamingSources.getProgress(for: title) {
                    ContinueWatchingCard(progress: progress, title: title, services: services)
                }

                // Streaming Sources Section
                streamingSourcesSection

                // Official Providers (TMDB/JustWatch)
                providerSection

                // TMDB Details
                tmdbDetailsSection

                // Recommendations
                if !model.recommendations.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Recommended")
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .padding(.horizontal, 20)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 13) {
                                ForEach(model.recommendations, id: \.listID) { recommendation in
                                    NavigationLink {
                                        DetailView(title: recommendation, services: services)
                                    } label: {
                                        PosterTile(title: recommendation)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }

                if !model.similar.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Similar")
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .padding(.horizontal, 20)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 13) {
                                ForEach(model.similar, id: \.listID) { similar in
                                    NavigationLink {
                                        DetailView(title: similar, services: services)
                                    } label: {
                                        PosterTile(title: similar)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }

                if let reviews = model.reviews, !reviews.results.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Reviews")
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .padding(.horizontal, 20)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 13) {
                                ForEach(reviews.results.prefix(5)) { review in
                                    ReviewCard(review: review)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }

                // Action Buttons
                HStack(spacing: 12) {
                    Button {
                        Task {
                            if let trailerURL = await model.trailerURL() {
                                openURL(trailerURL)
                            }
                        }
                    } label: {
                        Label(model.isLoadingTrailer ? "Loading" : "Watch trailer", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(red: 1, green: 0.34, blue: 0.19), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(model.isLoadingTrailer)

                    Button { model.toggleSaved() } label: {
                        Image(systemName: model.isSaved ? "bookmark.fill" : "bookmark")
                            .frame(width: 52, height: 48)
                            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .accessibilityLabel(model.isSaved ? "Remove from My List" : "Add to My List")
                }
                .font(.system(size: 15, weight: .semibold))
                .buttonStyle(.plain)
                .padding(.horizontal, 20)

                Text("Streami is a discovery guide. Streaming sources are third-party and may not be available in all regions.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
        }
        .background(Color(red: 0.035, green: 0.045, blue: 0.06))
        .ignoresSafeArea(edges: .top)
        .toolbarBackground(.hidden, for: .navigationBar)
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
                    if let source = pendingSource ?? services.streamingSources.getBestSource(for: title.type == "movie" ? "movie" : "tv") {
                        play(source, season: selectedSeason, episode: episode)
                    }
                    pendingSource = nil
                }
            )
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

    // MARK: - Streaming Sources Section

    @ViewBuilder
    private var streamingSourcesSection: some View {
        let type = title.type == "movie" ? "movie" : "tv"
        let sources = services.streamingSources.enabledSources(for: type)
        let bestSource = services.streamingSources.getBestSource(for: type)

        if !sources.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Stream Online")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                    Spacer()
                    HStack(spacing: 8) {
                        if services.streamingSources.autoSelectBestSource, let best = bestSource {
                            Label("Auto", systemImage: "wand.and.stars")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.orange.opacity(0.2), in: Capsule())
                        }
                        Text("\(sources.count) sources")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // Show best source first if auto-select is enabled
                        let orderedSources = services.streamingSources.autoSelectBestSource && bestSource != nil
                            ? [bestSource!] + sources.filter { $0.id != bestSource!.id }
                            : sources
                        
                        ForEach(orderedSources) { source in
                            SourceButton(
                                source: source,
                                title: title,
                                progress: services.streamingSources.getProgress(for: title),
                                isBestAutoSource: services.streamingSources.autoSelectBestSource && bestSource?.id == source.id,
                                onTap: {
                                    if title.type == "tv" && (selectedSeason == nil || selectedEpisode == nil) {
                                        pendingSource = source
                                        showSeasonPicker = true
                                    } else {
                                        play(source, season: selectedSeason, episode: selectedEpisode)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    // MARK: - Provider Section (Official)

    @ViewBuilder
    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Where to watch")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                Spacer()
                Text(model.regionCode)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.55))
            }

            if model.isLoadingProviders {
                ProgressView().tint(.white)
            } else if let providerError = model.providerError {
                VStack(alignment: .leading, spacing: 8) {
                    Text(providerError)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.65))
                    Button("Try again") { Task { await model.loadSupportingData() } }
                        .font(.footnote.weight(.semibold))
                }
            } else if let providerRegion = model.providerRegion {
                ProviderGroup(title: "Subscription", providers: providerRegion.streaming ?? [])
                ProviderGroup(title: "Free", providers: providerRegion.freeOptions ?? [])
                ProviderGroup(title: "Free with ads", providers: providerRegion.ads ?? [])
                ProviderGroup(title: "Rent", providers: providerRegion.rent ?? [])
                ProviderGroup(title: "Buy", providers: providerRegion.buy ?? [])

                if let link = providerRegion.link {
                    Link(destination: link) {
                        Label("See all options", systemImage: "arrow.up.right")
                            .font(.subheadline.weight(.semibold))
                    }
                }

                if (providerRegion.streaming ?? []).isEmpty && (providerRegion.freeOptions ?? []).isEmpty &&
                    (providerRegion.ads ?? []).isEmpty && (providerRegion.rent ?? []).isEmpty &&
                    (providerRegion.buy ?? []).isEmpty {
                    Text("No listings are available for this title in \(model.regionCode).")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Text("Availability data by JustWatch. Listings can change.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            } else {
                Text("No listings are available for this title in \(model.regionCode).")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(16)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var tmdbDetailsSection: some View {
        if let details = model.details {
            VStack(alignment: .leading, spacing: 16) {
                if let genres = details.genres, !genres.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Genres")
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .padding(.horizontal, 20)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(genres) { genre in
                                    Text(genre.name)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.82))
                                        .padding(.horizontal, 11)
                                        .padding(.vertical, 7)
                                        .background(.white.opacity(0.09), in: Capsule())
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }

                if let runtime = model.displayRuntime {
                    Label(runtime, systemImage: "clock")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.62))
                        .padding(.horizontal, 20)
                }

                if let certification = model.certification {
                    Label(certification, systemImage: "checkmark.shield")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 20)
                }

                if !model.directors.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.directors.count == 1 ? "Director" : "Directors")
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .padding(.horizontal, 20)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(model.directors) { director in
                                    VStack(spacing: 4) {
                                        if let url = director.profileURL {
                                            KFImage(url)
                                                .placeholder { Circle().fill(.white.opacity(0.1)) }
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 60, height: 60)
                                                .clipShape(Circle())
                                        } else {
                                            Circle()
                                                .fill(.white.opacity(0.1))
                                                .frame(width: 60, height: 60)
                                                .overlay(Image(systemName: "person.fill").foregroundStyle(.white.opacity(0.3)))
                                        }
                                        Text(director.name)
                                            .font(.caption.weight(.medium))
                                            .lineLimit(2)
                                            .frame(width: 70)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }

                if !model.creators.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Creators")
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .padding(.horizontal, 20)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(model.creators) { creator in
                                    VStack(spacing: 4) {
                                        if let url = creator.profileURL {
                                            KFImage(url)
                                                .placeholder { Circle().fill(.white.opacity(0.1)) }
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 60, height: 60)
                                                .clipShape(Circle())
                                        } else {
                                            Circle()
                                                .fill(.white.opacity(0.1))
                                                .frame(width: 60, height: 60)
                                                .overlay(Image(systemName: "person.fill").foregroundStyle(.white.opacity(0.3)))
                                        }
                                        Text(creator.name)
                                            .font(.caption.weight(.medium))
                                            .lineLimit(2)
                                            .frame(width: 70)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }

                if let status = details.status {
                    Text(status.capitalized)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.62))
                        .padding(.horizontal, 20)
                }

                if let tagline = details.tagline, !tagline.isEmpty {
                    Text(tagline)
                        .font(.subheadline.italic())
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 20)
                }

            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Continue Watching Card

struct ContinueWatchingCard: View {
    let progress: WatchProgress
    let title: TMDBTitle
    let services: AppServices
    @State private var showPlayer = false

    private var titleWithIMDB: TMDBTitle {
        // TMDB numeric IDs work on every enabled source.
        return title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Continue Watching")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                Spacer()
                if let source = services.streamingSources.sources.first(where: { $0.id == progress.sourceID }) {
                    Text(source.name)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 20)

            Button {
                showPlayer = true
            } label: {
                HStack(spacing: 16) {
                    KFImage(title.posterURL)
                        .placeholder { Rectangle().fill(Color(red: 0.09, green: 0.105, blue: 0.125)) }
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(alignment: .center) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.white)
                                .shadow(radius: 4)
                        }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(title.displayTitle)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        if let season = progress.season, let episode = progress.episode {
                            Text("Season \(season), Episode \(episode)")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }

                        // Progress bar
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("\(Int(progress.progress * 100))% watched")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                                Spacer()
                                Text(formatTime(progress.currentTime))
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            ProgressView(value: progress.progress)
                                .tint(.orange)
                        }
                    }
                }
                .padding(12)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
        }
        .fullScreenCover(isPresented: $showPlayer) {
            if let result = services.streamingSources.getBestSourceURL(for: title, season: progress.season, episode: progress.episode) {
                StreamingPlayerView(
                    title: title,
                    source: result.1,
                    season: progress.season,
                    episode: progress.episode
                )
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) % 3600 / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}

// MARK: - Source Button

struct SourceButton: View {
    let source: StreamingSource
    let title: TMDBTitle
    let progress: WatchProgress?
    let isBestAutoSource: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.1))
                        .frame(width: 56, height: 56)

                    Image(systemName: source.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.orange)
                    
                    if isBestAutoSource {
                        Circle()
                            .stroke(.orange, lineWidth: 2)
                            .frame(width: 56, height: 56)
                    }
                }

                Text(source.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(width: 70)

                if isBestAutoSource {
                    Text("AUTO")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(.orange.opacity(0.2), in: Capsule())
                }

                if let progress {
                    ProgressView(value: progress.progress)
                        .frame(width: 70)
                        .tint(.orange)
                        .scaleEffect(y: 0.5)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Source Selection Sheet

struct SourceSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: TMDBTitle
    let season: Int?
    let episode: Int?
    let streamingSources: StreamingSourceManager
    let onPlay: (StreamingSource, Int?, Int?) -> Void
    @State private var selectedSource: StreamingSource?
    @State private var useAutoSelect: Bool = true

    private var titleWithIMDB: TMDBTitle {
        // The IMDB ID is fetched in DetailViewModel
        return title
    }

    private var availableSources: [StreamingSource] {
        if title.type == "movie" {
            return streamingSources.enabledSources(for: "movie")
        } else {
            return streamingSources.enabledSources(for: "tv")
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Auto-select option
                Section {
                    Toggle(isOn: $useAutoSelect) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                                .font(.title2)
                                .foregroundStyle(.orange)
                                .frame(width: 40)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Auto-select best server")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Text("Automatically picks the fastest, most reliable source")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Continue watching section
                if let progress = streamingSources.getProgress(for: title, season: season, episode: episode),
                   let source = streamingSources.sources.first(where: { $0.id == progress.sourceID }) {
                    Section("Continue Watching") {
                        SourceRow(
                            source: source,
                            progress: progress,
                            isSelected: selectedSource?.id == source.id
                        ) {
                            selectedSource = source
                            useAutoSelect = false
                        }
                    }
                }

                Section("Available Sources") {
                    ForEach(availableSources) { source in
                        SourceRow(
                            source: source,
                            progress: streamingSources.getProgress(for: title, season: season, episode: episode),
                            isSelected: selectedSource?.id == source.id
                        ) {
                            selectedSource = source
                            useAutoSelect = false
                        }
                    }
                }
            }
            .navigationTitle("Choose Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Play") {
                        if useAutoSelect {
                            if let result = streamingSources.getBestSourceURL(for: title, season: season, episode: episode) {
                                dismiss()
                                onPlay(result.1, season, episode)
                            }
                        } else if let source = selectedSource {
                            dismiss()
                            onPlay(source, season, episode)
                        }
                    }
                    .disabled(!useAutoSelect && selectedSource == nil)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct SourceRow: View {
    let source: StreamingSource
    let progress: WatchProgress?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: source.icon)
                    .font(.title2)
                    .foregroundStyle(.orange)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(source.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)

                    if let progress {
                        HStack(spacing: 8) {
                            ProgressView(value: progress.progress)
                                .frame(width: 100)
                            Text("\(Int(progress.progress * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
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

// MARK: - Provider Group

private struct ProviderGroup: View {
    let title: String
    let providers: [TMDBWatchProvider]

    var body: some View {
        if !providers.isEmpty {
            VStack(alignment: .leading, spacing: 9) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.58))
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
                            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
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
                    .foregroundStyle(.white)
                Spacer()
                if let rating = review.authorDetails?.rating {
                    Text(String(format: "%.1f/10", rating))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.yellow)
                }
            }
            
            Text(review.content)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(4)
            
            Text(review.createdAt.prefix(10))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(12)
        .frame(width: 280)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
}
