import SwiftUI
import Kingfisher

private enum CatalogGridStyle {
    static let background = Color(red: 0.035, green: 0.045, blue: 0.06)
    static let surface = Color(red: 0.09, green: 0.105, blue: 0.125)
    static let muted = Color(red: 0.62, green: 0.65, blue: 0.7)
}

struct CatalogPosterGrid: View {
    @Environment(AppServices.self) private var services
    let titles: [TMDBTitle]

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 138, maximum: 210), spacing: 14, alignment: .top)]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .center, spacing: 22) {
            ForEach(titles, id: \.listID) { title in
                NavigationLink(value: title) {
                    CatalogPosterCard(title: title)
                }
                .buttonStyle(.plain)
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
        .padding(.horizontal, 18)
        .padding(.vertical, 4)
    }
}

private struct CatalogPosterCard: View {
    let title: TMDBTitle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                KFImage(title.posterURL)
                    .placeholder {
                        Rectangle()
                            .fill(CatalogGridStyle.surface)
                            .overlay {
                                Image(systemName: "film")
                                    .font(.title2)
                                    .foregroundStyle(CatalogGridStyle.muted)
                            }
                    }
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .aspectRatio(2 / 3, contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.64)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if let rating = title.voteAverage {
                    Label(rating.formatted(.number.precision(.fractionLength(1))), systemImage: "star.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.58), in: Capsule())
                        .padding(9)
                }
            }

            Text(title.displayTitle)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .topLeading)

            HStack(spacing: 5) {
                Text(title.type == "tv" ? "Series" : "Movie")
                if !title.year.isEmpty {
                    Text("·")
                    Text(title.year)
                }
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(CatalogGridStyle.muted)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct CatalogGridSkeleton: View {
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 138, maximum: 210), spacing: 14, alignment: .top)]
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 22) {
            ForEach(0..<8, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(CatalogGridStyle.surface)
                        .aspectRatio(2 / 3, contentMode: .fit)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(CatalogGridStyle.surface)
                        .frame(height: 13)
                        .padding(.trailing, 20)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(CatalogGridStyle.surface)
                        .frame(width: 60, height: 10)
                }
                .redacted(reason: .placeholder)
            }
        }
        .padding(.horizontal, 18)
    }
}

struct CatalogEmptyState: View {
    let title: String
    let message: String
    let symbol: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(title: String, message: String, symbol: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.symbol = symbol
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(CatalogGridStyle.muted)
            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(CatalogGridStyle.muted)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .padding(.horizontal, 28)
    }
}