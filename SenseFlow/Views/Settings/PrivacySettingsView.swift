import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct PrivacySettingsView: View {
    @Bindable var model: SettingsModel
    @ObservedObject private var permissions = PermissionStatusCoordinator.shared
    @State private var appNames: [String: String] = [:]
    private var excludedApps: [String] {
        Array(Set(model.filterAppListString.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })).sorted()
    }
    var body: some View {
        SettingsFormContainer {
            SettingsSection(title: "数据存储") {
                Text("历史记录保存在本机。")
                    .font(.pingFang(size: 13))
                Text("系统标记为密码、隐藏或临时的内容不会进入历史。使用在线工具时，处理所需的内容会发送给你选择的服务。")
                    .font(.pingFang(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            SettingsSection(title: "排除的应用") {
                if excludedApps.isEmpty {
                    Text("未添加应用。").font(.pingFang(.caption)).foregroundStyle(.secondary)
                }
                ForEach(excludedApps, id: \.self) { identifier in
                    HStack {
                        Text(appNames[identifier] ?? "已排除的应用")
                        Spacer()
                        Button {
                            model.filterAppListString = excludedApps.filter { $0 != identifier }.joined(separator: "\n")
                        } label: { Image(systemName: "minus.circle") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                        .accessibilityLabel("移除 \(appNames[identifier] ?? "应用")")
                    }
                }
                Button("添加应用…", systemImage: "plus") { chooseApp() }.buttonStyle(.bordered)
            }
            SettingsSection(title: "系统权限") {
                permissionRow("辅助功能", detail: "用于把内容填入其他应用的输入框。", granted: permissions.snapshot.accessibilityGranted, anchor: "Privacy_Accessibility")
            }
        }
        .onAppear { permissions.start(consumer: .settings); refreshNames() }
        .onDisappear { permissions.stop(consumer: .settings) }
        .onChange(of: model.filterAppListString) { _, _ in refreshNames() }
    }
    private func permissionRow(_ title: String, detail: String, granted: Bool, anchor: String) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title).font(.pingFang(size: 13, weight: .medium))
                    Text(granted ? "已授权" : "未授权").font(.pingFang(.caption)).foregroundStyle(.secondary)
                }
                Text(detail).font(.pingFang(.caption)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button("系统设置…") {
                guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else { return }
                NSWorkspace.shared.open(url)
            }.buttonStyle(.bordered)
        }
    }
    private func refreshNames() {
        appNames = Dictionary(uniqueKeysWithValues: excludedApps.map { identifier in
            let name = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier)?.deletingPathExtension().lastPathComponent
            return (identifier, name ?? "未安装的应用")
        })
    }
    private func chooseApp() {
        let picker = NSOpenPanel()
        picker.allowedContentTypes = [.applicationBundle]
        picker.directoryURL = URL(fileURLWithPath: "/Applications")
        picker.canChooseDirectories = false
        picker.prompt = "添加"
        picker.begin { response in
            guard response == .OK, let url = picker.url, let identifier = Bundle(url: url)?.bundleIdentifier else { return }
            model.filterAppListString = Array(Set(excludedApps + [identifier])).sorted().joined(separator: "\n")
        }
    }
}
