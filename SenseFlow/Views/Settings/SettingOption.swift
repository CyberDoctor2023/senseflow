import SwiftUI

/// User-facing settings destinations, ordered by everyday use.
enum SettingOption: String, Equatable, Hashable, Identifiable, CaseIterable {
    case general, clipboard, appearance, shortcuts, privacy, promptTools
    var id: String { rawValue }
    var title: String {
        switch self {
        case .general: "通用"
        case .clipboard: "剪贴板"
        case .appearance: "外观"
        case .shortcuts: "快捷键"
        case .promptTools: "一组工具"
        case .privacy: "隐私"
        }
    }
    var symbolName: String {
        switch self {
        case .general: "slider.horizontal.3"
        case .clipboard: "clipboard"
        case .appearance: "circle.lefthalf.filled"
        case .shortcuts: "keyboard"
        case .promptTools: "wand.and.stars"
        case .privacy: "hand.raised"
        }
    }
    @MainActor @ViewBuilder func viewForPage(model: SettingsModel) -> some View {
        switch self {
        case .general: GeneralSettingsView(model: model)
        case .clipboard: ClipboardSettingsView()
        case .appearance: AppearanceSettingsView()
        case .shortcuts: ShortcutSettingsView()
        case .promptTools: PromptToolsSettingsView()
        case .privacy: PrivacySettingsView(model: model)
        }
    }
}
