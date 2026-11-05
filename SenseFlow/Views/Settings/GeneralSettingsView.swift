import SwiftUI
import ServiceManagement

/// App lifecycle and update preferences only.
struct GeneralSettingsView: View {
    @Bindable var model: SettingsModel
    @State private var launchError: String?
    var body: some View {
        SettingsFormContainer {
            SettingsSection(title: "启动") {
                SettingsToggle(title: "登录时启动", isOn: $model.launchAtLogin)
                    .onChange(of: model.launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                if let launchError { Text(launchError).font(.pingFang(.caption)).foregroundStyle(.red) }
            }
            AppUpdateSettingsView()
        }
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

/// History categories and system capture collection share one settings destination.
struct ClipboardSettingsView: View {
    @AppStorage("filter_text_enabled") private var textEnabled = true
    @AppStorage("filter_image_enabled") private var imageEnabled = true
    @AppStorage("filter_code_enabled") private var codeEnabled = true
    @AppStorage("filter_link_enabled") private var linkEnabled = true
    @AppStorage("filter_screenshot_enabled") private var screenshotEnabled = false
    @AppStorage("filter_recording_enabled") private var recordingEnabled = false
    @ObservedObject private var captures = SystemCaptureService.shared
    var body: some View {
        SettingsFormContainer {
            SettingsSection(title: "分类筛选") {
                SettingsToggle(title: "文字", isOn: $textEnabled)
                SettingsToggle(title: "图片", isOn: $imageEnabled)
                SettingsToggle(title: "代码", isOn: $codeEnabled)
                SettingsToggle(title: "链接", isOn: $linkEnabled)
                SettingsToggle(title: "截图", isOn: $screenshotEnabled, detail: "按系统标记检索，读取受保护文件时需授权。")
                SettingsToggle(title: "录屏", isOn: $recordingEnabled, detail: "按系统标记检索，读取受保护文件时需授权。")
                Text("截图与录屏默认关闭，开启后自动检索，关闭后保留已导入的历史。")
                    .font(.pingFang(.caption)).foregroundStyle(.secondary)
            }
            if screenshotEnabled || recordingEnabled {
                Text(captures.errorMessage ?? captures.status).font(.pingFang(.caption))
                    .foregroundStyle(captures.errorMessage == nil ? Color.secondary : Color.red)
            }
        }
        .onChange(of: screenshotEnabled) { _, _ in
            captures.refreshCollection()
        }
        .onChange(of: recordingEnabled) { _, _ in
            captures.refreshCollection()
        }
    }
}

/// Visual preferences do not own clipboard collection or application lifecycle.
struct AppearanceSettingsView: View {
    @AppStorage(HistoryCardMotion.preferenceKey) private var cardMotion = HistoryCardMotion.wave
    var body: some View {
        SettingsFormContainer {
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
    }
}

/// Independent collection preferences with reversible fragment presentation.
struct BasicIntelligenceSettingsView: View {
    @AppStorage(UserDefaultsKeys.filterVoiceInput) private var filterVoiceInput = false
    @AppStorage(UserDefaultsKeys.replaceCoveredFragments) private var replaceCoveredFragments = false
    @State private var sourceStatus = ""

    var body: some View {
        SettingsFormContainer {
            SettingsSection(title: "采集整理") {
                SettingsToggle(title: "自动过滤无用内容", isOn: $filterVoiceInput,
                               detail: "跳过微信输入法为语音输入自动写入剪贴板的内容。")
                if filterVoiceInput {
                    Text(sourceStatus).font(.pingFang(.caption)).foregroundStyle(.secondary)
                }
                SettingsToggle(title: "完整片段覆盖", isOn: $replaceCoveredFragments,
                               detail: "同一应用两分钟内的新文本完全包含短片段时，仅显示完整文本。关闭后可查看原片段。")
            }
        }
        .onAppear { updateSourceObservation() }
        .onChange(of: filterVoiceInput) { _, _ in updateSourceObservation() }
        .onChange(of: replaceCoveredFragments) { _, _ in
            NotificationCenter.default.post(name: .clipboardDidUpdate, object: nil)
        }
    }

    private func updateSourceObservation() {
        VoiceInputSourceObserver.shared.setEnabled(filterVoiceInput)
        sourceStatus = VoiceInputSourceObserver.shared.isObserving
            ? "已启用来源进程识别，支持微信输入法。"
            : "来源进程识别暂不可用，请检查辅助功能权限。目前仅能识别带来源标记的内容。"
    }
}
