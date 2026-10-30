//
//  HotKeyRecorderView.swift
//  SenseFlow
//
//  Created by Claude on 2026-01-16.
//

import SwiftUI
import KeyboardShortcuts

/// 快捷键录制器视图
struct HotKeyRecorderView: View {
    @State private var currentConfig = HotKeyPreferences.load()
    @State private var isSyncingRecorder = false

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.spacing16) {
            KeyboardShortcuts.Recorder(for: HotKeyNames.main, onChange: applyRecordedShortcut)

            // 操作按钮
            HStack(spacing: Constants.spacing12) {
                Button(Strings.Buttons.reset) {
                    resetToDefaultShortcut()
                }
                .buttonStyle(.bordered)
            }


        }
        .onAppear {
            currentConfig = HotKeyPreferences.load()
        }
    }

    private func applyRecordedShortcut(_ shortcut: KeyboardShortcuts.Shortcut?) {
        guard !isSyncingRecorder else { return }
        guard let shortcut else {
            restoreRecorderWithCurrentConfig()
            return
        }

        let carbon = HotKeyShortcutCodec.toCarbon(shortcut)
        if carbon.keyCode == currentConfig.keyCode && carbon.modifiers == currentConfig.modifierFlags {
            return
        }

        let result = HotKeySettingsTransaction.apply(
            kind: .main,
            keyCode: carbon.keyCode,
            modifiers: carbon.modifiers
        )
        currentConfig = result.config
        guard result.success else {
            restoreRecorderWithCurrentConfig()
            return
        }

    }

    private func resetToDefaultShortcut() {
        let result = HotKeySettingsTransaction.resetToDefault(kind: .main)
        currentConfig = result.config
        guard result.success else {
            restoreRecorderWithCurrentConfig()
            return
        }

    }

    private func restoreRecorderWithCurrentConfig() {
        currentConfig = HotKeyPreferences.load()
        let shortcut = HotKeySettingsTransaction.currentShortcut(kind: .main)
        setRecorderShortcut(shortcut)
    }

    private func setRecorderShortcut(_ shortcut: KeyboardShortcuts.Shortcut?) {
        isSyncingRecorder = true
        KeyboardShortcuts.setShortcut(shortcut, for: HotKeyNames.main)
        DispatchQueue.main.async {
            isSyncingRecorder = false
        }
    }


}

#Preview {
    HotKeyRecorderView()
        .frame(width: Constants.DialogWindow.hotKeyRecorder)
        .padding()
}
