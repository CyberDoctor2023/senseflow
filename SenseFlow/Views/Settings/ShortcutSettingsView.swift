//
//  ShortcutSettingsView.swift
//  SenseFlow
//
//  Created by Claude on 2026-01-16.
//  Updated on 2026-01-26 for Form-based layout
//

import SwiftUI

/// 快捷键设置 Tab（Form-based layout per macOS standards）
struct ShortcutSettingsView: View {
    var body: some View {
        Form {
            Section(Strings.ShortcutSettings.sectionTitle) {
                HotKeyRecorderView()
                    .help(Strings.ShortcutSettings.recorderHelp)

                Text(Strings.ShortcutSettings.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .compatibleControlSize()
    }
}

#Preview {
    if #available(macOS 26.0, *) {
        ShortcutSettingsView()
            .frame(
                width: DesignSystem.WindowSize.settingsWindow.width,
                height: DesignSystem.WindowSize.settingsWindow.height
            )
    } else {
        Text(Strings.ShortcutSettings.previewFallback)
    }
}
