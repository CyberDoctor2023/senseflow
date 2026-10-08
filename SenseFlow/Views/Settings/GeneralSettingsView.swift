import SwiftUI
import ServiceManagement

struct GeneralSettingsView: View {
    @Bindable var model: SettingsModel
    @State private var launchError: String?
    @AppStorage(HistoryCardMotion.preferenceKey) private var cardMotion = HistoryCardMotion.wave
    @AppStorage("filter_text_enabled") private var textEnabled = true
    @AppStorage("filter_image_enabled") private var imageEnabled = true
    @AppStorage("filter_code_enabled") private var codeEnabled = true
    @AppStorage("filter_screenshot_enabled") private var screenshotEnabled = false
    @AppStorage("filter_recording_enabled") private var recordingEnabled = false
    @AppStorage(SystemCaptureService.importExistingKey) private var importExistingCaptures = true
    @ObservedObject private var captures = SystemCaptureService.shared
    var body: some View {
        SettingsFormContainer {
            SettingsSection(title: "分类筛选") {
                SettingsToggle(title: "文字", isOn: $textEnabled)
                SettingsToggle(title: "图片", isOn: $imageEnabled)
                SettingsToggle(title: "代码", isOn: $codeEnabled)
                SettingsToggle(title: "截图", isOn: $screenshotEnabled, detail: "按系统标记检索，读取受保护文件时需授权。")
                SettingsToggle(title: "录屏", isOn: $recordingEnabled, detail: "按系统标记检索，读取受保护文件时需授权。")
                Text("截图与录屏默认关闭，开启后自动检索，关闭后保留已导入的历史。")
                    .font(.pingFang(.caption)).foregroundStyle(.secondary)
            }
            SettingsSection(title: "系统截图与录屏") {
                SettingsToggle(title: "导入已有截图和录屏", isOn: $importExistingCaptures)
                Text(captures.errorMessage ?? captures.status).font(.pingFang(.caption))
                    .foregroundStyle(captures.errorMessage == nil ? Color.secondary : Color.red)
                Text("自动检索 Spotlight 已索引的截图和录屏。受保护文件的读取可能需要系统授权。")
                    .font(.pingFang(.caption)).foregroundStyle(.secondary)
            }
            SettingsSection(title: "启动") {
                SettingsToggle(title: "登录时启动", isOn: $model.launchAtLogin)
                    .onChange(of: model.launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                if let launchError { Text(launchError).font(.pingFang(.caption)).foregroundStyle(.red) }
            }
            SettingsSection(title: "卡片动效") {
                Picker("卡片动效", selection: $cardMotion) {
                    ForEach(HistoryCardMotion.allCases, id: \.self) { motion in
                        Text(motion.title).tag(motion)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text(cardMotion == .classic ? "保留经典的悬停与按压效果。" : "鼠标附近的卡片抬高，形成平滑的起伏。")
                    .font(.pingFang(.caption))
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: screenshotEnabled) { _, _ in
            captures.refreshCollection()
        }
        .onChange(of: recordingEnabled) { _, _ in
            captures.refreshCollection()
        }
        .onChange(of: importExistingCaptures) { _, _ in captures.refreshCollection() }
    }
    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            launchError = nil
        } catch {
            model.launchAtLogin = SMAppService.mainApp.status == .enabled
            launchError = "未能更新启动设置，请在系统设置的登录项中检查。"
        }
    }
}
