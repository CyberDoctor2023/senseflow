//
//  SettingsView.swift
//  SenseFlow
//
//  Created by Claude on 2026-01-16.
//  Updated on 2026-02-10 for Landmarks architecture alignment
//

import SwiftUI

/// 设置窗口主视图（完全对标 LandmarksSplitView 架构）
/// - 通过 @Environment 接收 SettingsModel（App 层注入）
/// - NavigationSplitView 侧边栏 + 详情面板
/// - SettingOption 独立 enum（对标 NavigationOptions）
struct SettingsView: View {
    @Environment(SettingsModel.self) var model
    @State private var selectedSetting: SettingOption? = .general

    var body: some View {
        @Bindable var model = model

        NavigationSplitView {
            List(selection: $selectedSetting) {
                Section {
                    ForEach(SettingOption.allCases) { option in
                        NavigationLink(value: option) {
                            Label(option.title, systemImage: option.symbolName)
                        }
                    }
                }
            }
            .frame(minWidth: Constants.SettingsForm.sidebarMinWidth)
            .navigationSplitViewColumnWidth(
                min: Constants.SettingsForm.sidebarMinWidth,
                ideal: Constants.SettingsForm.sidebarIdealWidth,
                max: Constants.SettingsForm.sidebarMaxWidth
            )
        } detail: {
            (selectedSetting ?? .general).viewForPage(model: model)
        }
    }
}

#Preview {
    @Previewable @State var model = SettingsModel()

    SettingsView()
        .environment(model)
        .frame(
            width: Constants.SettingsWindow.defaultWidth,
            height: Constants.SettingsWindow.defaultHeight
        )
}
