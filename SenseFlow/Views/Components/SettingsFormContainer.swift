//
//  SettingsFormContainer.swift
//  SenseFlow
//
//  Created on 2026-01-29
//

import SwiftUI

/// 统一的设置页面容器，解决以下问题：
/// 1. 左侧 sidebar 高度跳动问题：通过 ScrollView + 固定 frame 确保一致的布局高度
/// 2. 顶部横线问题：通过精确的 padding 控制移除不必要的分隔线
struct SettingsFormContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.top, Constants.spacing20)
                .padding(.horizontal, Constants.spacing20)
                .padding(.bottom, Constants.spacing20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // 移除自定义背景，让 Form 使用系统默认背景和材质
    }
}

#Preview {
    SettingsFormContainer {
        Form {
            Section("示例") {
                Toggle("选项 1", isOn: .constant(true))
                Toggle("选项 2", isOn: .constant(false))
            }
        }
        .formStyle(.grouped)
    }
    .frame(
        width: Constants.DialogWindow.settingsForm.width,
        height: Constants.DialogWindow.settingsForm.height
    )
}
