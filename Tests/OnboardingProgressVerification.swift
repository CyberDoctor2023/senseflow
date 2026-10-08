import Foundation
@testable import SenseFlow

/// Checks delayed progression and persistence without changing real preferences or clipboard data.
@main struct OnboardingProgressVerification {
    @MainActor static func main() async throws {
        let suite = "top.senseflow.verification.onboarding.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { throw Failure() }
        defer { defaults.removePersistentDomain(forName: suite) }
        let tour = ClipboardOnboardingCoordinator(defaults: defaults)
        try require(tour.step == .launch, "fresh tutorial waits for reveal")
        tour.historyScrolled(by: 100)
        try require(tour.step == .launch, "scrolling cannot skip reveal")
        tour.launchRequested()
        tour.historyScrolled(by: -100)
        try require(!tour.didSlideLeft && !tour.didSlideRight, "right movement before left does not complete instruction")
        tour.historyScrolled(by: 30)
        try require(tour.didSlideLeft && !tour.didSlideRight && tour.step == .history, "left alone cannot advance")
        tour.historyScrolled(by: -30)
        try await Task.sleep(for: .milliseconds(1100))
        try require(tour.step == .history && tour.isGuideLeaving, "both directions retain the leaving interval")
        tour.historyScrolled(by: 1)
        try require(!tour.isGuideLeaving, "continued scrolling cancels the pending transition")
        try await Task.sleep(for: .milliseconds(1700))
        try require(tour.step == .preview, "settled movement advances to preview")
        tour.previewOpened()
        tour.categorySelected()
        try await Task.sleep(for: .milliseconds(1700))
        try require(tour.step == .filters && !tour.didSelectCategory, "open preview does not skip close instruction")
        tour.previewClosed()
        tour.categorySelected()
        try await Task.sleep(for: .milliseconds(1700))
        try require(tour.step == .finished, "category selection advances after preview closes")
        var completions = 0
        tour.onComplete = { completions += 1 }
        tour.finishAutomatically()
        tour.finishAutomatically()
        try await Task.sleep(for: .milliseconds(1700))
        try require(tour.isComplete && completions == 1, "completion is delivered once")
        let restored = ClipboardOnboardingCoordinator(defaults: defaults)
        try require(restored.isComplete, "completed progress survives reconstruction")
        tour.restart()
        try require(tour.step == .launch && !tour.hasPreview && !tour.didSlideLeft && !tour.didSlideRight,
                    "restart clears interaction progress")
        print("PASS: isolated onboarding progress; native layout, shortcut and gesture visuals require separate verification")
    }
    static func require(_ value: Bool, _ message: String) throws {
        guard value else { print("FAIL: \(message)"); throw Failure() }
        print("PASS: \(message)")
    }
    struct Failure: Error {}
}
