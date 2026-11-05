import SwiftUI

/// User-facing settings destinations, ordered by everyday use.
enum SettingOption: String, Equatable, Hashable, Identifiable, CaseIterable {
    case general, clipboard, intelligence, appearance, shortcuts, privacy
    var id: String { rawValue }
    var title: String {
        switch self {
        case .general: "通用"
        case .clipboard: "剪贴板"
        case .intelligence: "基础智能"
        case .appearance: "外观"
        case .shortcuts: "快捷键"
        case .privacy: "隐私"
        }
    }
    var symbolName: String {
        switch self {
        case .general: "slider.horizontal.3"
        case .clipboard: "clipboard"
        case .intelligence: "sparkles"
        case .appearance: "circle.lefthalf.filled"
        case .shortcuts: "keyboard"
        case .privacy: "hand.raised"
        }
    }
    @MainActor @ViewBuilder func viewForPage(model: SettingsModel) -> some View {
        switch self {
        case .general: GeneralSettingsView(model: model)
        case .clipboard: ClipboardSettingsView()
        case .intelligence: BasicIntelligenceSettingsView()
        case .appearance: AppearanceSettingsView()
        case .shortcuts: ShortcutSettingsView()
        case .privacy: PrivacySettingsView(model: model)
        }
    }
}
