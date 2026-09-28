import SwiftUI
import UIKit

// MARK: - Streami Design System
// Cinema-dark theme: deep navy surfaces on black, rose-red accent.
// Spacing follows an 8pt rhythm; type uses rounded display + system text.

enum DS {
    // MARK: Colors
    static let background = Color(red: 0.0, green: 0.0, blue: 0.0)
    static let primary = Color(red: 0.059, green: 0.059, blue: 0.137)
    static let secondary = Color(red: 0.118, green: 0.106, blue: 0.294)
    static let surface = Color(red: 0.094, green: 0.094, blue: 0.094)
    static let card = Color(red: 0.11, green: 0.11, blue: 0.16)
    static let accent = Color(red: 0.882, green: 0.114, blue: 0.282)
    static let accentSoft = Color(red: 0.882, green: 0.114, blue: 0.282).opacity(0.16)
    static let gold = Color(red: 1.0, green: 0.8, blue: 0.2)
    static let foreground = Color(red: 0.973, green: 0.98, blue: 0.988)
    static let muted = Color(red: 0.62, green: 0.65, blue: 0.72)
    static let border = Color(red: 0.192, green: 0.18, blue: 0.506)
    static let success = Color(red: 0.2, green: 0.78, blue: 0.38)

    // MARK: Layout
    static let gutter: CGFloat = 20
    static let radiusSmall: CGFloat = 8
    static let radiusMedium: CGFloat = 12
    static let radiusLarge: CGFloat = 20
    static let posterW: CGFloat = 132
    static let posterH: CGFloat = 198
    static let heroHome: CGFloat = 400
    static let heroDetail: CGFloat = 260

    // MARK: Type
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    static func headline(_ size: CGFloat = 19) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    static let eyebrow = Font.system(size: 11, weight: .bold, design: .rounded)
}

// MARK: - Haptics

enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func select() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Press feedback (scale 0.97, no layout shift)

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Skeleton shimmer

struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1
    private var isReducedMotion: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                if !isReducedMotion {
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.14), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 0.6)
                        .offset(x: phase * geo.size.width * 1.4)
                    }
                    .mask(content)
                }
            }
            .onAppear {
                guard !isReducedMotion else { return }
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View { modifier(Shimmer()) }
}

// MARK: - Shared components

struct SectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(DS.headline())
                    .foregroundStyle(DS.foreground)
                Spacer()
            }
            if let subtitle {
                Text(subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DS.muted)
            }
        }
        .padding(.horizontal, DS.gutter)
        .accessibilityElement(children: .combine)
    }
}

struct RatingBadge: View {
    let rating: Double

    var body: some View {
        Label(
            rating.formatted(.number.precision(.fractionLength(1))),
            systemImage: "star.fill"
        )
        .font(.caption2.weight(.bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.black.opacity(0.62), in: Capsule())
    }
}

struct MetaPill: View {
    let text: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage).font(.caption2.weight(.bold))
            }
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(DS.foreground.opacity(0.85))
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(.white.opacity(0.1), in: Capsule())
    }
}

struct StreamiProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.16))
                Capsule()
                    .fill(DS.accent)
                    .frame(width: geo.size.width * max(0, min(1, progress)))
            }
        }
        .frame(height: 4)
        .accessibilityValue("\(Int(progress * 100)) percent watched")
    }
}

struct PrimaryCTA: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(DS.accent, in: RoundedRectangle(cornerRadius: DS.radiusMedium))
    }
}
