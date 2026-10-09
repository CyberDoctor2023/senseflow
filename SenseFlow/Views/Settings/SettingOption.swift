import SwiftUI

/// User-facing settings destinations, ordered by everyday use.
enum SettingOption: String, Equatable, Hashable, Identifiable, CaseIterable {
    case general, shortcuts, privacy, promptTools
    var id: String { rawValue }
    var title: String {
        switch self {
        case .general: "通用"
        case .shortcuts: "快捷键"
        case .promptTools: "一组工具"
        case .privacy: "隐私"
        }
    }
    var symbolName: String {
        switch self {
        case .general: "slider.horizontal.3"
        case .shortcuts: "keyboard"
        case .promptTools: "wand.and.stars"
        case .privacy: "hand.raised"
        }
    }
    @MainActor @ViewBuilder func viewForPage(model: SettingsModel) -> some View {
        switch self {
        case .general: GeneralSettingsView(model: model)
        case .shortcuts: ShortcutSettingsView()
        case .promptTools: PromptToolsSettingsView()
        case .privacy: PrivacySettingsView(model: model)
        }
    }
}
