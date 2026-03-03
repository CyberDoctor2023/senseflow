//
//  PromptToolEditorView.swift
//  SenseFlow
//
//  Created on 2026-01-19.
//

import SwiftUI
import KeyboardShortcuts

/// Prompt Tool 编辑器 Sheet
struct PromptToolEditorView: View {
    let tool: PromptTool?
    let onSave: (PromptTool) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var prompt: String
    @State private var selectedCapabilities: Set<PromptToolCapability>
    @State private var shortcutKeyCode: UInt16
    @State private var shortcutModifiers: UInt32

    private var isNewTool: Bool { tool == nil }

    init(tool: PromptTool?, onSave: @escaping (PromptTool) -> Void, onCancel: @escaping () -> Void) {
        self.tool = tool
        self.onSave = onSave
        self.onCancel = onCancel

        // Initialize @State variables immediately with tool data
        _name = State(initialValue: tool?.name ?? "")
        _prompt = State(initialValue: tool?.prompt ?? "")
        _selectedCapabilities = State(initialValue: Set(tool?.capabilities ?? []))
        _shortcutKeyCode = State(initialValue: tool?.shortcutKeyCode ?? 0)
        _shortcutModifiers = State(initialValue: tool?.shortcutModifiers ?? 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            HStack {
                Text(isNewTool ? "新建 Prompt Tool" : "编辑 Prompt Tool")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // MARK: - Form
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 名称
                    VStack(alignment: .leading, spacing: 4) {
                        Text("名称")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextField("例如：Markdown 格式化", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Prompt
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Prompt 模板")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        TextEditor(text: $prompt)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: Constants.TextEditor.minHeight)
                            .overlay(
                                RoundedRectangle(cornerRadius: Constants.cornerRadiusSmall)
                                    .stroke(Color.gray.opacity(Constants.opacity30), lineWidth: Constants.borderWidth1)
                            )

                        Text("用户的剪贴板内容会作为「用户输入」追加到此 Prompt 后面")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // 能力标签
                    VStack(alignment: .leading, spacing: 8) {
                        Text("能力标签")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            ForEach(PromptToolCapability.allCases, id: \.rawValue) { capability in
                                Button {
                                    toggleCapability(capability)
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: selectedCapabilities.contains(capability) ? "checkmark.circle.fill" : "circle")
                                        Text(capability.displayName)
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(selectedCapabilities.contains(capability) ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.12))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Text("推荐时优先使用能力标签，再回退到名称/Prompt启发式")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // 快捷键
                    VStack(alignment: .leading, spacing: 4) {
                        Text("快捷键（可选）")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        ShortcutRecorderField(
                            keyCode: $shortcutKeyCode,
                            modifiers: $shortcutModifiers,
                            editingToolID: tool?.id
                        )
                    }
                }
                .padding()
            }

            Divider()

            // MARK: - Footer
            HStack {
                Button("取消") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("保存") {
                    saveTool()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || prompt.isEmpty)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: Constants.DialogWindow.promptToolEditor.width, height: Constants.DialogWindow.promptToolEditor.height)
    }

    private func saveTool() {
        let updatedTool = PromptTool(
            id: tool?.id ?? UUID(),
            name: name,
            prompt: prompt,
            capabilities: selectedCapabilities.sorted(by: { $0.rawValue < $1.rawValue }),
            shortcutKeyCode: shortcutKeyCode,
            shortcutModifiers: shortcutModifiers,
            isDefault: tool?.isDefault ?? false,
            createdAt: tool?.createdAt ?? Date(),
            updatedAt: Date(),
            source: tool?.source ?? .custom,
            remoteId: tool?.remoteId,
            remoteAuthor: tool?.remoteAuthor,
            remoteVotes: tool?.remoteVotes ?? 0,
            remoteUpdatedAt: tool?.remoteUpdatedAt,
            langfuseName: tool?.langfuseName,
            langfuseVersion: tool?.langfuseVersion,
            langfuseLabels: tool?.langfuseLabels ?? [],
            lastSyncedAt: tool?.lastSyncedAt
        )
        onSave(updatedTool)
    }

    private func toggleCapability(_ capability: PromptToolCapability) {
        if selectedCapabilities.contains(capability) {
            selectedCapabilities.remove(capability)
            return
        }
        selectedCapabilities.insert(capability)
    }
}

// MARK: - Shortcut Recorder Field

struct ShortcutRecorderField: View {
    @Binding var keyCode: UInt16
    @Binding var modifiers: UInt32
    let editingToolID: UUID?

    @State private var showConflictAlert = false
    @State private var isSyncingRecorder = false
    @State private var isRecorderActive = false
    @State private var shortcutBeforeRecording: KeyboardShortcuts.Shortcut?
    @State private var showNoChangeHint = false

    private let recorderStatusNotification = Notification.Name("KeyboardShortcuts_recorderActiveStatusDidChange")

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                KeyboardShortcuts.Recorder(for: HotKeyNames.toolEditorRecorder, onChange: handleRecorderChange)

                if keyCode != 0 {
                    Button {
                        keyCode = 0
                        modifiers = 0
                        setRecorderShortcut(nil)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }

            if showNoChangeHint {
                Text("快捷键未变更：通常表示该组合被系统/菜单占用，或本次录制已取消。")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .onAppear {
            syncRecorderWithBinding()
        }
        .onDisappear {
            KeyboardShortcuts.setShortcut(nil, for: HotKeyNames.toolEditorRecorder)
        }
        .onChange(of: keyCode) {
            syncRecorderWithBinding()
        }
        .onChange(of: modifiers) {
            syncRecorderWithBinding()
        }
        .onReceive(NotificationCenter.default.publisher(for: recorderStatusNotification)) { event in
            let active = event.userInfo?["isActive"] as? Bool ?? false

            if active {
                isRecorderActive = true
                shortcutBeforeRecording = KeyboardShortcuts.getShortcut(for: HotKeyNames.toolEditorRecorder)
                showNoChangeHint = false
                return
            }

            guard isRecorderActive else { return }
            isRecorderActive = false

            let current = KeyboardShortcuts.getShortcut(for: HotKeyNames.toolEditorRecorder)
            if current == shortcutBeforeRecording {
                showNoChangeHint = true
            }
        }
        .alert("快捷键冲突", isPresented: $showConflictAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("该快捷键已被其他应用占用，请选择其他组合。")
        }
    }

    private func handleRecorderChange(_ shortcut: KeyboardShortcuts.Shortcut?) {
        guard !isSyncingRecorder else { return }
        showNoChangeHint = false

        guard let shortcut else {
            keyCode = 0
            modifiers = 0
            return
        }

        let carbon = HotKeyShortcutCodec.toCarbon(shortcut)
        let isConflicted: Bool
        if let editingToolID {
            isConflicted = AppHotKeyCoordinator.shared.isToolHotKeyConflicted(
                toolID: ToolID(editingToolID),
                keyCode: carbon.keyCode,
                modifiers: carbon.modifiers
            )
        } else {
            isConflicted = AppHotKeyCoordinator.shared.isHotKeyConflicted(
                keyCode: carbon.keyCode,
                modifiers: carbon.modifiers
            )
        }

        if isConflicted {
            showConflictAlert = true
            syncRecorderWithBinding()
            return
        }

        keyCode = UInt16(carbon.keyCode)
        modifiers = carbon.modifiers
    }

    private func syncRecorderWithBinding() {
        let shortcut: KeyboardShortcuts.Shortcut?
        if keyCode == 0 {
            shortcut = nil
        } else {
            shortcut = HotKeyShortcutCodec.toShortcut(keyCode: keyCode, modifiers: modifiers)
        }
        setRecorderShortcut(shortcut)
    }

    private func setRecorderShortcut(_ shortcut: KeyboardShortcuts.Shortcut?) {
        isSyncingRecorder = true
        KeyboardShortcuts.setShortcut(shortcut, for: HotKeyNames.toolEditorRecorder)
        DispatchQueue.main.async {
            isSyncingRecorder = false
        }
    }
}

#Preview {
    if #available(macOS 26.0, *) {
        PromptToolEditorView(
            tool: nil,
            onSave: { _ in },
            onCancel: {}
        )
    } else {
        Text("需要 macOS 13.0+")
    }
}
