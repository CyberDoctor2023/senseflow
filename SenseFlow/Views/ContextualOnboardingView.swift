import SwiftUI
import AskForPermission

private struct ClipboardOnboardingKey: EnvironmentKey {
    static let defaultValue: ClipboardOnboardingCoordinator? = nil
}
extension EnvironmentValues {
    var clipboardOnboarding: ClipboardOnboardingCoordinator? {
        get { self[ClipboardOnboardingKey.self] }
        set { self[ClipboardOnboardingKey.self] = newValue }
    }
}

enum OnboardingTarget: Hashable { case history, search, pin, textFilter, imageFilter, codeFilter, linkFilter, screenshotFilter, recordingFilter, card(Int64), edit, save, preview }
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
        self.overlayPreferenceValue(OnboardingAnchors.self) { anchors in
            if let coordinator, let step = inPreview ? coordinator.previewStep : coordinator.historyStep, step != .launch {
                GeometryReader { geometry in
                    if step == .finished {
                        Color.clear
                            .allowsHitTesting(false)
                            .task { coordinator.finishAutomatically() }
                    } else {
                        ContextualOnboardingOverlay(coordinator: coordinator, step: step,
                            anchors: anchors, geometry: geometry, hasRecords: hasRecords)
                            .id(step)
                            .transition(.opacity)
                        if step == .filters, anchors[.preview] == nil,
                           let imageFilter = anchors[.imageFilter] {
                            let button = geometry[imageFilter.bounds]
                            OnboardingFilterPointer()
                                .frame(width: 36, height: 40)
                                .position(x: min(button.midX + 18, geometry.size.width - 32),
                                          y: min(button.midY + 18, geometry.size.height - 24))
                                .transition(.opacity)
                        }
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
    @State private var permissionFeedback: String?

    private var title: String {
        switch step {
        case .launch: return "按下 " + HotKeyPreferences.load().displayString + "，打开剪贴板"
        case .history: return "滑动以查看"
        case .filters: return anchors[.preview] != nil ? "轻点别处以关闭预览" : "按" + categoryTargets.map(\.1).joined(separator: "、") + "筛选"
        case .preview: return "长按或按压以预览"
        case .accessibility: return "最后一步：开启权限"
        case .finished: return ""
        case .complete: return ""
        }
    }
    private var categoryTargets: [(OnboardingTarget, String)] {
        [(.textFilter, "文字"), (.imageFilter, "图片"), (.codeFilter, "代码")]
            .filter { anchors[$0.0] != nil }
    }
    private var calloutWidth: CGFloat { min(480, max(220, geometry.size.width - 32)) }
    private var calloutCenter: CGPoint {
        if anchors[.preview] != nil {
            return CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        let controls: [OnboardingTarget] = [.search, .textFilter, .imageFilter, .codeFilter, .screenshotFilter, .recordingFilter]
        let toolbarEnd = controls.compactMap { anchors[$0].map { geometry[$0.bounds].maxX } }.max() ?? 0
        let searchY = anchors[.search].map { geometry[$0.bounds].midY } ?? 40
        return CGPoint(x: min(toolbarEnd + calloutWidth / 2 + 24, geometry.size.width - calloutWidth / 2 - 16),
                       y: max(searchY, step == .accessibility || step == .filters ? 56 : 40))
    }
    /// Keep the feather's transparent edge inside the native window, including narrow toolbars.
    private var calloutBlurRegion: CGRect {
        let center = calloutCenter
        let halfHeight = max(0, min(70, center.y - 4, geometry.size.height - center.y - 4))
        let halfWidth = max(0, min(calloutWidth / 2 + 110, center.x - 4, geometry.size.width - center.x - 4))
        return CGRect(x: center.x - halfWidth, y: center.y - halfHeight,
                      width: halfWidth * 2, height: halfHeight * 2)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            OnboardingFeatheredBlur(regions: [calloutBlurRegion])
            VStack(spacing: 14) {
                if step == .accessibility {
                    HStack(spacing: 18) {
                        OnboardingSettingsThumbnail(systemSettings: true)
                            .frame(width: 94, height: 66)
                        Text("最后一步：开启权限")
                    }
                    .font(OnboardingGuidanceStyle.titleFont)
                    .contentShape(.rect)
                    .requestsPermission(.accessibility, showWhenAuthorized: true) { result in
                        switch result {
                        case .authorized, .alreadyAuthorized: coordinator.deferAccessibility()
                        case .cancelled: permissionFeedback = nil
                        case .timedOut: permissionFeedback = "尚未完成，可再次尝试"
                        case .unavailable: permissionFeedback = "未能打开系统设置，请重试"
                        }
                    }
                    .simultaneousGesture(TapGesture().onEnded { coordinator.permissionRequested() })
                    .accessibilityElement(children: .ignore)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("开启辅助功能权限")
                    if let permissionFeedback {
                        Text(permissionFeedback).font(.pingFang(size: 16)).foregroundStyle(.secondary)
                    }
                } else {
                    HStack(spacing: 18) {
                        if step == .history || step == .preview || (step == .filters && anchors[.preview] != nil) {
                            ClipboardFingerDemo(vertical: false, travel: 34,
                                pressing: step == .preview, tapping: step == .filters)
                                .frame(width: 94, height: 66)
                                .accessibilityLabel(step == .history ? "触控板双指左右滑动" : step == .preview ? "触控板长按或按压以预览" : "触控板轻点别处以关闭预览")
                        }
                        VStack(spacing: 8) {
                            Text(title).font(OnboardingGuidanceStyle.titleFont)
                                .multilineTextAlignment(.center)
                            if step == .filters && anchors[.preview] == nil {
                                Text("更多类别，可在设置中选择")
                                    .font(.pingFang(size: 18))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .frame(width: calloutWidth, alignment: .center)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(.primary.opacity(0.86))
            .offset(y: reduceMotion || revealed ? 0 : 4)
            .opacity(revealed && !coordinator.isGuideLeaving ? 1 : 0)
            .animation(.easeInOut(duration: 0.45), value: coordinator.isGuideLeaving)
            .position(calloutCenter)
            .accessibilityElement(children: .contain)
            .task(id: step) {
                if step == .finished { coordinator.finishAutomatically() }
            }

        }

        .font(.pingFang(size: 13))
        .opacity(coordinator.isGuideLeaving ? 0 : 1)
        .animation(.easeInOut(duration: 0.45), value: coordinator.isGuideLeaving)
        .onAppear {
            if step == .accessibility { AskForPermission.configure(appName: "senseflow") }
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
                                .fill(.white)
                                .mask {
                                    LinearGradient(stops: [
                                        .init(color: .clear, location: 0),
                                        .init(color: .white, location: 0.22),
                                        .init(color: .white, location: 0.78),
                                        .init(color: .clear, location: 1)
                                    ], startPoint: .leading, endPoint: .trailing)
                                }
                                .mask {
                                    LinearGradient(stops: [
                                        .init(color: .clear, location: 0),
                                        .init(color: .white, location: 0.28),
                                        .init(color: .white, location: 0.72),
                                        .init(color: .clear, location: 1)
                                    ], startPoint: .top, endPoint: .bottom)
                                }
                                .frame(width: rect.width, height: rect.height)
                                .position(x: rect.midX, y: rect.midY)
                        }
                    }
                }
            }
            .allowsHitTesting(false)
    }
}

/// Shared trackpad illustration for reveal, horizontal browsing, and press gestures.
struct ClipboardFingerDemo: View {
    let vertical: Bool
    let travel: CGFloat
    var pressing = false
    var tapping = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private enum Phase: CaseIterable {
        case reset, appear, slide, pause, disappear
        case returnReset, returnAppear, returnSlide, returnPause, returnDisappear
        var returning: Bool {
            switch self {
            case .returnReset, .returnAppear, .returnSlide, .returnPause, .returnDisappear: true
            default: false
            }
        }
        var atStart: Bool { self == .reset || self == .appear || self == .returnReset || self == .returnAppear }
        var hidden: Bool { self == .reset || self == .disappear || self == .returnReset || self == .returnDisappear }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Group {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.94))
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.gray.opacity(0.48), lineWidth: 2.5)
                }
                if reduceMotion {
                    fingers(trail: false)
                } else if pressing || tapping {
                    Circle().fill(Color(red: 0.38, green: 0.55, blue: 0.77))
                        .frame(width: 18, height: 18)
                        .phaseAnimator([false, true]) { dot, pressed in
                            dot.scaleEffect(pressed ? 1.22 : 1)
                                .opacity(pressed ? 1 : 0.75)
                                .shadow(color: .black.opacity(pressed ? 0.08 : 0.18),
                                        radius: pressed ? 1 : 3, y: pressed ? 1 : 4)
                        } animation: { pressed in
                            .easeInOut(duration: tapping ? (pressed ? 0.16 : 1.25) : (pressed ? 0.7 : 0.9))
                        }
                } else {
                    Color.clear
                        .phaseAnimator(vertical ? [.reset, .appear, .slide, .disappear] : Phase.allCases) { content, phase in
                            let atStart = phase.atStart
                            let start: CGFloat = vertical ? -geometry.size.height * 0.1 : phase.returning ? -travel / 2 : travel / 2
                            let end: CGFloat = vertical ? -geometry.size.height / 2 - 20 : -start
                            fingers(trail: true, movingRight: phase.returning)
                                .offset(x: vertical ? 0 : atStart ? start : end,
                                        y: vertical ? atStart ? start : end : 0)
                                .opacity(phase.hidden ? 0 : 1)
                        } animation: { phase in
                            switch phase {
                            case .reset, .returnReset: .linear(duration: 0.9)
                            case .appear, .returnAppear: .easeInOut(duration: 0.2)
                            case .slide, .returnSlide: .smooth(duration: vertical ? 0.7 : 1.1)
                            case .pause, .returnPause: .linear(duration: 0.9)
                            case .disappear, .returnDisappear: .easeOut(duration: 0.2)
                            }
                        }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .allowsHitTesting(false)
    }

    private func fingers(trail: Bool, movingRight: Bool = false) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<((pressing || tapping) ? 1 : 2)) { _ in
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

/// A schematic settings window, sharing the trackpad illustration's footprint.
private struct OnboardingSettingsThumbnail: View {
    let systemSettings: Bool

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 5) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .medium))
                ForEach(0..<3) { _ in
                    Capsule().fill(.secondary.opacity(0.2)).frame(width: 12, height: 2)
                }
            }
            .frame(width: 28, height: 66)
            .background(.primary.opacity(0.04))
            VStack(alignment: .leading, spacing: 7) {
                Image(systemName: systemSettings ? "accessibility" : "slider.horizontal.3")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(red: 0.38, green: 0.55, blue: 0.77))
                ForEach(0..<2) { _ in
                    Capsule().fill(.secondary.opacity(0.22)).frame(height: 3)
                }
            }
            .padding(10)
        }
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.94))
        .clipShape(.rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.gray.opacity(0.48), lineWidth: 2.5)
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(systemSettings ? "系统设置中的辅助功能" : "senseflow设置中的类别选项")
    }
}

/// A non-interactive cursor points at the real image-filter anchor.
private struct OnboardingFilterPointer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Phase: CaseIterable {
        case point, left, right, settle
        var angle: Double {
            switch self {
            case .point, .settle: 0
            case .left: -14
            case .right: 14
            }
        }
        var duration: Double {
            switch self {
            case .point: 1.2
            case .left, .right: 0.65
            case .settle: 0.55
            }
        }
    }

    private var cursorOutline: Path {
        Path { path in
            path.move(to: CGPoint(x: 5, y: 3))
            path.addQuadCurve(to: CGPoint(x: 2, y: 6), control: CGPoint(x: 1, y: 1))
            path.addLine(to: CGPoint(x: 7, y: 28))
            path.addQuadCurve(to: CGPoint(x: 11, y: 29), control: CGPoint(x: 8, y: 33))
            path.addLine(to: CGPoint(x: 16, y: 19))
            path.addLine(to: CGPoint(x: 25, y: 16))
            path.addQuadCurve(to: CGPoint(x: 25, y: 12), control: CGPoint(x: 29, y: 14))
            path.closeSubpath()
        }
    }

    private var cursor: some View {
        cursorOutline.fill(Color(white: 0.48))
            .overlay {
                cursorOutline.stroke(.white.opacity(0.95),
                    style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
            }
            .frame(width: 28, height: 32)
            .shadow(color: .black.opacity(0.18), radius: 3, y: 2)
    }

    var body: some View {
        Group {
            if reduceMotion {
                cursor
            } else {
                cursor.phaseAnimator(Phase.allCases) { pointer, phase in
                    pointer.rotationEffect(.degrees(phase.angle), anchor: .center)
                } animation: { phase in
                    .easeInOut(duration: phase.duration)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Shared typography for all tutorial chapters; placement follows the current operation.
enum OnboardingGuidanceStyle {
    static let titleFont = Font.pingFang(size: 28, weight: .medium)
}
