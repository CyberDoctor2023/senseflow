import SwiftUI

private struct ClipboardOnboardingKey: EnvironmentKey {
    static let defaultValue: ClipboardOnboardingCoordinator? = nil
}
extension EnvironmentValues {
    var clipboardOnboarding: ClipboardOnboardingCoordinator? {
        get { self[ClipboardOnboardingKey.self] }
        set { self[ClipboardOnboardingKey.self] = newValue }
    }
}

enum OnboardingTarget: Hashable { case history, search, pin, textFilter, imageFilter, codeFilter, screenshotFilter, recordingFilter, card(Int64), edit, save, preview }
struct OnboardingAnchor {
    let bounds: Anchor<CGRect>
    let radius: CGFloat
}
struct OnboardingAnchors: PreferenceKey {
    static let defaultValue: [OnboardingTarget: OnboardingAnchor] = [:]
    static func reduce(value: inout [OnboardingTarget: OnboardingAnchor], nextValue: () -> [OnboardingTarget: OnboardingAnchor]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

extension View {
    func onboardingTarget(_ target: OnboardingTarget, radius: CGFloat = 20) -> some View {
        anchorPreference(key: OnboardingAnchors.self, value: .bounds) {
            [target: OnboardingAnchor(bounds: $0, radius: radius)]
        }
    }
    func contextualOnboarding(_ coordinator: ClipboardOnboardingCoordinator?, inPreview: Bool = false, hasRecords: Bool = true) -> some View {
        overlayPreferenceValue(OnboardingAnchors.self) { anchors in
            if let coordinator, let step = inPreview ? coordinator.previewStep : coordinator.historyStep, step != .launch {
                GeometryReader { geometry in
                    if step == .finished {
                        Color.clear
                            .allowsHitTesting(false)
                            .task { coordinator.finishAutomatically() }
                    } else if step == .history, let history = anchors[.history] {
                        let viewport = geometry[history.bounds]
                        ClipboardHistoryGuide(tour: coordinator)
                            .frame(width: viewport.width, height: viewport.height)
                            .position(x: viewport.midX, y: viewport.midY)
                            .transition(.opacity)
                    } else if step != .history {
                        ContextualOnboardingOverlay(coordinator: coordinator, step: step,
                            anchors: anchors, geometry: geometry, hasRecords: hasRecords)
                            .id(step)
                            .transition(.opacity)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.45), value: inPreview ? coordinator?.previewStep : coordinator?.historyStep)
    }
}

/// Anchor-driven mask; decorative layers pass input through, while the callout remains interactive.
private struct ContextualOnboardingOverlay: View {
    let coordinator: ClipboardOnboardingCoordinator
    let step: ClipboardOnboardingCoordinator.Step
    let anchors: [OnboardingTarget: OnboardingAnchor]
    let geometry: GeometryProxy
    let hasRecords: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    private var targets: [OnboardingTarget] {
        switch step {
        case .launch: return []
        case .history: return [.history]
        case .filters: return anchors[.preview] != nil ? [.preview] : [.textFilter, .imageFilter, .codeFilter]
        case .preview:
            let viewport = anchors[.history].map { geometry[$0.bounds] } ?? CGRect(origin: .zero, size: geometry.size)
            let cards = anchors.keys.filter {
                guard case .card = $0, let anchor = anchors[$0] else { return false }
                return viewport.contains(geometry[anchor.bounds])
            }.sorted { left, right in
                guard let lhs = anchors[left], let rhs = anchors[right] else { return false }
                return geometry[lhs.bounds].minX < geometry[rhs.bounds].minX
            }
            return cards.first.map { [$0] } ?? [.textFilter]
        case .finished, .complete: return []
        }
    }
    private var holes: [(CGRect, CGFloat)] {
        targets.compactMap { target in
            guard let anchor = anchors[target] else { return nil }
            return (geometry[anchor.bounds], anchor.radius)
        }
    }
    private var targetRect: CGRect {
        holes.reduce(CGRect.null) { $0.union($1.0) }
    }
    private var width: CGFloat { min(260, max(180, geometry.size.width - 32)) }
    private var calloutCenter: CGPoint {
        let viewport = anchors[.history].map { geometry[$0.bounds] } ?? CGRect(origin: .zero, size: geometry.size)
        if anchors[.preview] != nil { return CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2) }
        let rect = targetRect.isNull ? viewport : targetRect
        let point: CGPoint
        switch step {
        case .filters: point = CGPoint(x: rect.maxX + width / 2 + 24, y: rect.midY)
        case .preview:
            let search = anchors[.search].map { geometry[$0.bounds] }
            point = CGPoint(x: max(rect.midX, (search?.maxX ?? 0) + width / 2 + 24),
                            y: search?.midY ?? max(32, viewport.minY - 28))
        default: point = CGPoint(x: viewport.midX, y: viewport.midY)
        }
        return CGPoint(x: min(max(point.x, width / 2 + 16), geometry.size.width - width / 2 - 16),
                       y: min(max(point.y, 32), geometry.size.height - 32))
    }
    private var title: String {
        switch step {
        case .launch: return "按下 " + HotKeyPreferences.load().displayString + "，打开剪贴板"
        case .history: return "左右滑动"
        case .filters: return anchors[.preview] != nil ? "轻点别处以关闭预览" : "按图片文字代码筛选"
        case .preview: return "长按或按压以预览"
        case .finished: return ""
        case .complete: return ""
        }
    }
    private var arrowPointsLeft: Bool {
        (step == .filters || step == .preview || targets == [.textFilter]) && calloutCenter.x - width / 2 > targetRect.maxX
    }
    private var arrowEnd: CGPoint {
        if arrowPointsLeft { return CGPoint(x: targetRect.maxX + 10, y: targetRect.midY) }
        return CGPoint(x: targetRect.midX, y: calloutCenter.y < targetRect.midY ? targetRect.minY - 8 : targetRect.maxY + 8)
    }

    private var blurRegions: [CGRect] {
        return [CGRect(x: calloutCenter.x - width / 2 - 30, y: calloutCenter.y - 60,
            width: width + 60, height: 120)]
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            OnboardingFeatheredBlur(regions: blurRegions)
            if !targetRect.isNull && step != .history && step != .finished && anchors[.preview] == nil {
                Path { path in
                    let start = arrowPointsLeft
                        ? CGPoint(x: calloutCenter.x - width / 2 - 6, y: calloutCenter.y)
                        : CGPoint(x: calloutCenter.x, y: calloutCenter.y + (calloutCenter.y < targetRect.midY ? 58 : -58))
                    let end = arrowEnd
                    path.move(to: start)
                    path.addQuadCurve(to: end, control: CGPoint(x: start.x, y: end.y))
                }.trim(from: 0, to: revealed ? 1 : 0)
                .stroke(.primary.opacity(0.65), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .allowsHitTesting(false)
                Image(systemName: arrowPointsLeft ? "arrow.left" : calloutCenter.y < targetRect.midY ? "arrow.down" : "arrow.up")
                    .font(.pingFang(size: 22, weight: .bold))
                    .foregroundStyle(.primary.opacity(0.65))
                    .position(arrowEnd)
                    .opacity(revealed ? 1 : 0).allowsHitTesting(false)
            }
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(title).font(.pingFang(size: 20, weight: .semibold))
                    Spacer()
                }
                HStack(spacing: 20) {
                }.font(.pingFang(size: 11)).padding(.top, 5)
            }
            .frame(width: width, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(.primary)
            
            .scaleEffect(revealed ? 1 : 0.98)
            .opacity(revealed ? 1 : 0)
            .position(calloutCenter)
            .accessibilityElement(children: .contain)
            .task(id: step) {
                if step == .finished { coordinator.finishAutomatically() }
            }
            Button("退出教程") { coordinator.skip() }
                .buttonStyle(.plain)
                .font(.pingFang(size: 12))
                .padding(8)
                .position(x: geometry.size.width - 112, y: 32)

        }
        .font(.pingFang(size: 13))
        .opacity(coordinator.isGuideLeaving ? 0 : 1)
        .animation(.easeInOut(duration: 0.45), value: coordinator.isGuideLeaving)
        .onAppear {
            withAnimation(.easeInOut(duration: reduceMotion ? 0 : 0.5)) { revealed = true }
        }
    }
}

/// One fixed material layer, with only its alpha mask positioned around instruction text.
struct OnboardingFeatheredBlur: View {
    let regions: [CGRect]
    var body: some View {
        Rectangle()
            .fill(.regularMaterial)
            .mask {
                GeometryReader { _ in
                    ZStack(alignment: .topLeading) {
                        ForEach(Array(regions.enumerated()), id: \.offset) { _, rect in
                            Rectangle()
                                .fill(EllipticalGradient(stops: [
                                    .init(color: .white, location: 0),
                                    .init(color: .white, location: 0.35),
                                    .init(color: .clear, location: 1)
                                ], center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5))
                                .frame(width: rect.width, height: rect.height)
                                .position(x: rect.midX, y: rect.midY)
                        }
                    }
                }
            }
            .allowsHitTesting(false)
    }
}

/// Native phase interpolation; only the launch demo has a trackpad outline.
struct ClipboardFingerDemo: View {
    let vertical: Bool
    let travel: CGFloat
    var movingRight = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private enum Phase: CaseIterable { case reset, appear, slide, pause, disappear }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if vertical {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.94))
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.gray.opacity(0.48), lineWidth: 2.5)
                }
                if reduceMotion {
                    fingers(trail: false)
                } else {
                    fingers(trail: true)
                        .phaseAnimator(vertical ? [.reset, .appear, .slide, .disappear] : Phase.allCases) { content, phase in
                            let atStart = phase == .reset || phase == .appear
                            let start: CGFloat = vertical ? -geometry.size.height * 0.1 : movingRight ? -travel / 2 : travel / 2
                            let end: CGFloat = vertical ? -geometry.size.height / 2 - 20 : -start
                            content
                                .offset(x: vertical ? 0 : atStart ? start : end,
                                        y: vertical ? atStart ? start : end : 0)
                                .opacity(phase == .reset || phase == .disappear ? 0 : 1)
                        } animation: { phase in
                            switch phase {
                            case .reset: .linear(duration: 0.9)
                            case .appear: .easeInOut(duration: 0.2)
                            case .slide: .smooth(duration: vertical ? 0.7 : 1.1)
                            case .pause: .linear(duration: 0.9)
                            case .disappear: .easeOut(duration: 0.2)
                            }
                        }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .allowsHitTesting(false)
    }

    private func fingers(trail: Bool) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<2) { _ in
                Circle().fill(Color(red: 0.38, green: 0.55, blue: 0.77))
                    .frame(width: 15, height: 15)
                    .background {
                        if trail {
                            Capsule()
                                .fill(LinearGradient(colors: [.clear, .black.opacity(0.16)],
                                    startPoint: vertical ? .bottom : movingRight ? .leading : .trailing,
                                    endPoint: vertical ? .top : movingRight ? .trailing : .leading))
                                .frame(width: vertical ? 14 : 30, height: vertical ? 30 : 14)
                                .blur(radius: 4)
                                .offset(x: vertical ? 0 : movingRight ? -10 : 10, y: vertical ? 10 : 0)
                        }
                    }
            }
        }
    }
}

struct ClipboardHistoryGuide: View {
    let tour: ClipboardOnboardingCoordinator
    @State private var appeared = false
    var body: some View {
        GeometryReader { geometry in
            ClipboardFingerDemo(vertical: false, travel: geometry.size.width / 3, movingRight: tour.didSlideLeft)
                .id(tour.didSlideLeft)
                .frame(width: min(geometry.size.width - 24, geometry.size.width / 3 + 90), height: min(140, geometry.size.height - 24))
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .opacity(appeared && !tour.isGuideLeaving ? 1 : 0)
        .animation(.easeInOut(duration: 0.45), value: appeared)
        .animation(.easeInOut(duration: 0.45), value: tour.isGuideLeaving)
        .onAppear { appeared = true }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("用鼠标滚轮或触控板双指左右滑动，翻看历史记录")
    }
}
