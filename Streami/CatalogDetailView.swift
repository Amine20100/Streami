import SwiftUI
import Kingfisher

private enum ProviderAvailabilityFilter: String, CaseIterable, Identifiable {
    case all = "All options"
    case subscription = "Subscription"
    case free = "Free"
    case ads = "Free with ads"
    case rent = "Rent"
    case buy = "Buy"

    var id: String { rawValue }
}

struct CatalogDetailView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.openURL) private var openURL
    let title: TMDBTitle
    @State private var model: DetailViewModel
    @State private var providerFilter = ProviderAvailabilityFilter.all

    init(title: TMDBTitle, services: AppServices) {
        self.title = title
        _model = State(wrappedValue: DetailViewModel(
            title: title,
            session: services.session,
            preferences: services.preferences,
            watchlist: services.watchlist
        ))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                hero

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

                if let details = model.details {
                    if let genres = details.genres, !genres.isEmpty {
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

                    if let runtime = details.displayRuntime {
                        Label(runtimeText(runtime), systemImage: "clock")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.62))
                            .padding(.horizontal, 20)
                    }

                    if !details.cast.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Cast")
                                .font(.system(size: 19, weight: .bold, design: .rounded))
                                .padding(.horizontal, 20)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(alignment: .top, spacing: 12) {
                                    ForEach(details.cast) { member in
                                        CastCard(member: member)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                } else if model.isLoadingDetails {
                    ProgressView().tint(.white).padding(.horizontal, 20)
                } else if let error = model.detailsError {
                    Label(error, systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.58))
                        .padding(.horizontal, 20)
                }

                if let overview = title.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.body)
                        .lineSpacing(5)
                        .foregroundStyle(.white.opacity(0.82))
                        .padding(.horizontal, 20)
                }

                providerSection
                recommendationsSection
                actions

                Text("Streami is a discovery guide. TMDB lists availability; playback is provided by licensed services.")
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
        .task(id: "\(title.type)-\(title.id)-\(model.regionCode)") {
            await model.wrappedValue.loadSupportingData()
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            KFImage(title.backdropURL)
                .placeholder {
                    Rectangle().fill(Color(red: 0.09, green: 0.105, blue: 0.125))
                }
                .resizable()
                .scaledToFill()
                .frame(height: 300)
                .clipped()
            LinearGradient(
                colors: [.clear, Color(red: 0.035, green: 0.045, blue: 0.06)],
                startPoint: .center,
                endPoint: .bottom
            )
            Text(title.displayTitle)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .lineLimit(2)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
    }

    @ViewBuilder
    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Where to watch")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                Spacer()
                Menu {
                    ForEach(ProviderAvailabilityFilter.allCases) { filter in
                        Button(filter.rawValue) { providerFilter = filter }
                    }
                } label: {
                    Label(providerFilter.rawValue, systemImage: "line.3.horizontal.decrease")
                        .font(.caption.weight(.semibold))
                }
                .accessibilityLabel("Filter provider availability")
            }

            Text("\(model.regionCode) region")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.48))

            if model.isLoadingProviders {
                ProgressView().tint(.white)
            } else if let error = model.providerError {
                VStack(alignment: .leading, spacing: 8) {
                    Text(error).font(.footnote).foregroundStyle(.white.opacity(0.65))
                    Button("Try again") { Task { await model.wrappedValue.loadSupportingData() } }
                        .font(.footnote.weight(.semibold))
                }
            } else if let region = model.providerRegion {
                let selectedProviders = providers(for: providerFilter, in: region)
                if selectedProviders.isEmpty {
                    Text(providerFilter == .all ? "No listings are available in \(model.regionCode)." : "No \(providerFilter.rawValue.lowercased()) options are listed here.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.6))
                } else {
                    ForEach(selectedProviders, id: \.title) { group in
                        LicensedProviderGroup(title: group.title, providers: group.providers)
                    }
                }

                if let link = region.link, !selectedProviders.isEmpty {
                    Link(destination: link) {
                        Label("See all options", systemImage: "arrow.up.right")
                            .font(.subheadline.weight(.semibold))
                    }
                }

                Text("Availability data by JustWatch. Listings can change.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            } else {
                Text("No listings are available in \(model.regionCode).")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(16)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var recommendationsSection: some View {
        if model.isLoadingRecommendations {
            HStack(spacing: 9) {
                ProgressView().tint(.white)
                Text("Finding similar titles")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
            }
            .padding(.horizontal, 20)
        } else if let error = model.recommendationsError {
            HStack {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.58))
                Spacer()
                Button("Retry") { Task { await model.wrappedValue.loadSupportingData() } }
                    .font(.footnote.weight(.semibold))
            }
            .padding(.horizontal, 20)
        } else if !model.recommendations.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("More like this")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .padding(.horizontal, 20)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 13) {
                        ForEach(model.recommendations, id: \.listID) { recommendation in
                            NavigationLink {
                                CatalogDetailView(title: recommendation, services: services)
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
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button {
                Task {
                    if let url = await model.wrappedValue.trailerURL() { openURL(url) }
                }
            } label: {
                Label("Watch trailer", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(red: 1, green: 0.34, blue: 0.19), in: RoundedRectangle(cornerRadius: 10))
            }
            .disabled(model.isLoadingTrailer)

            Button { model.wrappedValue.toggleSaved() } label: {
                Image(systemName: model.isSaved ? "bookmark.fill" : "bookmark")
                    .frame(width: 52, height: 48)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityLabel(model.isSaved ? "Remove from My List" : "Add to My List")
        }
        .font(.system(size: 15, weight: .semibold))
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    private func runtimeText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours == 0 { return "\(minutes) min" }
        if remainder == 0 { return "\(hours) hr" }
        return "\(hours) hr \(remainder) min"
    }

    private func providers(for filter: ProviderAvailabilityFilter, in region: TMDBProviderRegion) -> [(title: String, providers: [TMDBWatchProvider])] {
        switch filter {
        case .all:
            return [
                ("Subscription", region.streaming ?? []),
                ("Free", region.freeOptions ?? []),
                ("Free with ads", region.ads ?? []),
                ("Rent", region.rent ?? []),
                ("Buy", region.buy ?? [])
            ].filter { !$0.providers.isEmpty }
        case .subscription:
            return [("Subscription", region.streaming ?? [])].filter { !$0.providers.isEmpty }
        case .free:
            return [("Free", region.freeOptions ?? [])].filter { !$0.providers.isEmpty }
        case .ads:
            return [("Free with ads", region.ads ?? [])].filter { !$0.providers.isEmpty }
        case .rent:
            return [("Rent", region.rent ?? [])].filter { !$0.providers.isEmpty }
        case .buy:
            return [("Buy", region.buy ?? [])].filter { !$0.providers.isEmpty }
        }
    }
}

private struct CastCard: View {
    let member: TMDBCastMember

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            KFImage(member.profileURL)
                .placeholder {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.08))
                        .overlay(Image(systemName: "person.fill").foregroundStyle(.white.opacity(0.35)))
                }
                .resizable()
                .scaledToFill()
                .frame(width: 86, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(member.name)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
                .frame(width: 86, alignment: .leading)
            Text(member.creditDescription)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(2)
                .frame(width: 86, alignment: .leading)
        }
    }
}

private struct LicensedProviderGroup: View {
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