import SwiftUI

struct ShortcutSettingsView: View {
    var body: some View {
        SettingsFormContainer {
            SettingsSection(title: "打开剪贴板") { HotKeyRecorderView() }
        }
    }
}
