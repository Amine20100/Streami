import SwiftUI
import Observation

// MARK: - Search icon micro-interaction
//
// Premium morph: tab-bar Search icon flies along a curved path to the top,
// then expands into the search field. Background veils with glass, results
// rise in after expansion. Fully reversed on close. Instant when
// Reduce Motion is enabled.

// MARK: Phases + anchors

enum SearchMorphPhase {
    case idle
    case pressing
    case flying
    case expanding
    case open
    case collapsing
    case returning
}

struct SearchIconAnchorKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct SearchBarAnchorKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// MARK: - Controller

@Observable
@MainActor
final class SearchMorphController {
    var phase: SearchMorphPhase = .idle
    var t: Double = 0 // flight progress 0...1
    var expand: Double = 0 // bar expansion 0...1
    var resultsMix: Double = 0 // results reveal 0...1
    var animateEntrance = false
    var iconFrame: CGRect = .zero
    var barFrame: CGRect = .zero

    private var run: Task<Void, Never>?

    var isTransitioning: Bool {
        switch phase {
        case .idle, .open: false
        default: true
        }
    }

    var isReducedMotion: Bool { UIAccessibility.isReduceMotionEnabled }

    func open() {
        run?.cancel()
        run = nil
        if isReducedMotion {
            t = 1
            expand = 1
            resultsMix = 1
            animateEntrance = false
            phase = .open
            return
        }
        animateEntrance = true
        t = 0
        expand = 0
        resultsMix = 0
        run = Task { [weak self] in await self?.runOpen() }
    }

    func close() async {
        run?.cancel()
        run = nil
        if isReducedMotion || phase == .idle {
            phase = .idle
            animateEntrance = false
            return
        }
        await runClose()
    }

    private func runOpen() async {
        phase = .pressing
        try? await Task.sleep(for: .milliseconds(80))
        guard !Task.isCancelled else { return }
        phase = .flying
        withAnimation(.easeIn(duration: 0.45)) { self.t = 1 }
        try? await Task.sleep(for: .milliseconds(450))
        guard !Task.isCancelled else { return }
        Haptics.tap()
        phase = .expanding
        withAnimation(.easeOut(duration: 0.30)) { self.expand = 1 }
        try? await Task.sleep(for: .milliseconds(200))
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.25)) { self.resultsMix = 1 }
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }
        phase = .open
    }

    private func runClose() async {
        if Task.isCancelled { return }
        phase = .collapsing
        withAnimation(.easeIn(duration: 0.12)) { self.resultsMix = 0 }
        try? await Task.sleep(for: .milliseconds(120))
        if Task.isCancelled { return }
        withAnimation(.easeIn(duration: 0.25)) { self.expand = 0 }
        try? await Task.sleep(for: .milliseconds(250))
        if Task.isCancelled { return }
        phase = .returning
        withAnimation(.easeInOut(duration: 0.40)) { self.t = 0 }
        try? await Task.sleep(for: .milliseconds(400))
        if Task.isCancelled { return }
        phase = .idle
        animateEntrance = false
    }
}

// MARK: - Reveal helper (results container)

extension View {
    /// Fade + rise 20pt once the bar expansion is nearly complete.
    func searchReveal(_ m: SearchMorphController, lift: CGFloat = 20) -> some View {
        self
            .opacity(m.animateEntrance ? m.resultsMix : 1)
            .offset(y: m.animateEntrance ? lift * CGFloat(1 - m.resultsMix) : 0)
    }
}

// MARK: - Press feedback (95% for 80ms)

struct MicroPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

// MARK: - Curve math

private func quad(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ t: CGFloat) -> CGPoint {
    let u = 1 - t
    return CGPoint(
        x: u * u * p0.x + 2 * u * t * p1.x + t * t * p2.x,
        y: u * u * p0.y + 2 * u * t * p1.y + t * t * p2.y
    )
}

private func quadTangent(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ t: CGFloat) -> CGVector {
    let dx = 2 * (1 - t) * (p1.x - p0.x) + 2 * t * (p2.x - p1.x)
    let dy = 2 * (1 - t) * (p1.y - p0.y) + 2 * t * (p2.y - p1.y)
    let len = max(hypot(dx, dy), 0.001)
    return CGVector(dx: dx / len, dy: dy / len)
}

// MARK: - Overlay

struct SearchMorphOverlay: View {
    var controller: SearchMorphController

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let p0 = origin(size: size)
            let p2 = destination(size: size)
            let p1 = control(p0: p0, p2: p2)
            let veil = 0.38 * max(controller.t, controller.expand) * (1 - 0.9 * controller.resultsMix)

            ZStack {
                if veil > 0.003 {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(min(veil * 1.2, 0.55))
                    Color.black.opacity(veil)
                }

                if controller.phase == .pressing || controller.phase == .flying || controller.phase == .returning {
                    trailBeam(p0: p0, p1: p1, p2: p2)
                    trailGhosts(p0: p0, p1: p1, p2: p2)
                    flyer(p0: p0, p1: p1, p2: p2)
                }

                if controller.phase == .expanding || controller.phase == .collapsing {
                    morphBar(size: size)
                    landingBurst(size: size)
                }
            }
            .frame(width: size.width, height: size.height)
        }
    }

    // MARK: Anchors (with safe fallbacks)

    private func origin(size: CGSize) -> CGPoint {
        guard controller.iconFrame != .zero else {
            return CGPoint(x: size.width / 2, y: size.height - 140)
        }
        return CGPoint(x: controller.iconFrame.midX, y: controller.iconFrame.midY - 6)
    }

    private func destination(size: CGSize) -> CGPoint {
        guard controller.barFrame != .zero else {
            return CGPoint(x: size.width / 2, y: 110)
        }
        return CGPoint(x: controller.barFrame.midX, y: controller.barFrame.midY)
    }

    private func control(p0: CGPoint, p2: CGPoint) -> CGPoint {
        let mid = CGPoint(x: (p0.x + p2.x) / 2, y: (p0.y + p2.y) / 2)
        let dx = Double(p2.x - p0.x)
        let dy = Double(p2.y - p0.y)
        let dist = max(hypot(dx, dy), 1)
        var nx = -dy / dist
        var ny = dx / dist
        if nx < 0 {
            nx = -nx
            ny = -ny
        }
        let bow = dist * 0.14
        return CGPoint(x: mid.x + CGFloat(nx * bow), y: mid.y + CGFloat(ny * bow))
    }

    private func flightPoint(p0: CGPoint, p1: CGPoint, p2: CGPoint, t: Double) -> CGPoint {
        var pt = quad(p0, p1, p2, CGFloat(t))
        // Anticipation: brief wind-up opposite the launch direction.
        if t > 0, t < 0.12 {
            let tan = quadTangent(p0, p1, p2, 0)
            let back = CGFloat((1 - t / 0.12) * 7)
            pt.x -= tan.dx * back
            pt.y -= tan.dy * back
        }
        return pt
    }

    // MARK: Flyer

    private func flyer(p0: CGPoint, p1: CGPoint, p2: CGPoint) -> some View {
        let t = controller.t
        let pt = flightPoint(p0: p0, p1: p1, p2: p2, t: t)
        let arc = sin(t * .pi)
        let scale: CGFloat = controller.phase == .pressing ? 0.95 : 0.95 + 0.05 * CGFloat(t)
        return Image(systemName: "magnifyingglass")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 46, height: 46)
            .background(Color(red: 0.11, green: 0.11, blue: 0.13), in: Circle())
            .overlay(Circle().stroke(DS.accent.opacity(0.7), lineWidth: 1.5))
            .shadow(color: DS.accent.opacity(0.55 * arc + 0.15), radius: CGFloat(14 * arc + 6))
            .blur(radius: CGFloat(4 * arc))
            .rotationEffect(.degrees(12 * arc))
            .scaleEffect(scale)
            .position(pt)
    }

    private func trailGhosts(p0: CGPoint, p1: CGPoint, p2: CGPoint) -> some View {
        let t = controller.t
        return ZStack {
            ForEach(1...3, id: \.self) { k in
                let tt = t - 0.07 * Double(k)
                if tt > 0 {
                    let pt = flightPoint(p0: p0, p1: p1, p2: p2, t: tt)
                    Circle()
                        .fill(DS.accent.opacity(0.28 / Double(k)))
                        .frame(width: 34, height: 34)
                        .blur(radius: 7)
                        .position(pt)
                }
            }
        }
    }

    private func trailBeam(p0: CGPoint, p1: CGPoint, p2: CGPoint) -> some View {
        let t = controller.t
        let a = flightPoint(p0: p0, p1: p1, p2: p2, t: max(t - 0.15, 0))
        let b = flightPoint(p0: p0, p1: p1, p2: p2, t: t)
        let dist = hypot(b.x - a.x, b.y - a.y)
        let angle = atan2(b.y - a.y, b.x - a.x)
        return Group {
            if dist > 10, t > 0.05, t < 0.98 {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.clear, DS.accent.opacity(0.45)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: CGFloat(dist + 24), height: 10)
                    .rotationEffect(.radians(angle))
                    .position(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
                    .blur(radius: 5)
                    .opacity(0.55 * sin(min(t * 1.2, 1) * .pi))
            }
        }
    }

    // MARK: Morph (icon rect -> search bar rect)

    private func morphRect(size: CGSize) -> (CGRect, CGRect) {
        let from: CGRect = controller.iconFrame != .zero
            ? controller.iconFrame
            : CGRect(x: origin(size: size).x - 23, y: origin(size: size).y - 23, width: 46, height: 46)
        let to: CGRect = controller.barFrame != .zero
            ? controller.barFrame
            : CGRect(x: 16, y: destination(size: size).y - 25, width: size.width - 32, height: 50)
        return (from, to)
    }

    private func morphBar(size: CGSize) -> some View {
        let e = controller.expand
        let (from, to) = morphRect(size: size)
        let w = from.width + (to.width - from.width) * CGFloat(e)
        let h = from.height + (to.height - from.height) * CGFloat(e)
        let x = from.midX + (to.midX - from.midX) * CGFloat(e)
        let y = from.midY + (to.midY - from.midY) * CGFloat(e)
        let scale: CGFloat = 1 + 0.05 * CGFloat(sin(e * .pi))
        let placeholderOpacity = max(0, min(1, (e - 0.35) / 0.4))
        let shimmerX = CGFloat(e * 2 - 1) * (w / 2 + 40)

        return ZStack {
            Capsule()
                .fill(Color(red: 0.11, green: 0.11, blue: 0.13))
                .frame(width: w, height: h)
                .overlay(Capsule().stroke(DS.accent.opacity(0.55), lineWidth: 1))
                .shadow(color: DS.accent.opacity(0.30 * (1 - e) + 0.08), radius: 14)
            // Light sweep across the bar as it forms.
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.28), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 70, height: h)
                .offset(x: shimmerX)
                .mask(Capsule().frame(width: w, height: h))
                .opacity(e > 0.05 && e < 0.98 ? 1 : 0)
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.7))
                Text("Search movies, shows, genres...")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .opacity(placeholderOpacity)
                    .offset(x: CGFloat((1 - placeholderOpacity) * 8))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(width: w, height: h)
            .clipShape(Capsule())
        }
        .scaleEffect(scale)
        .position(x: x, y: y)
    }

    private func landingBurst(size: CGSize) -> some View {
        let progress = min(controller.expand * 2.5, 1)
        let center = destination(size: size)
        return Group {
            if progress < 1 {
                ZStack {
                    ForEach(0..<12, id: \.self) { i in
                        let angle = Double(i) / 12 * 2 * .pi + 0.3
                        let dist = 16 + Double((i * 37) % 22)
                        let dot: CGFloat = i % 3 == 0 ? 5 : 3.5
                        Circle()
                            .fill(i % 3 == 0 ? DS.accent : Color.white)
                            .frame(width: dot, height: dot)
                            .offset(
                                x: CGFloat(cos(angle) * dist * progress),
                                y: CGFloat(sin(angle) * dist * progress)
                            )
                            .opacity((1 - progress) * 0.9)
                    }
                }
                .position(center)
            }
        }
    }
}
