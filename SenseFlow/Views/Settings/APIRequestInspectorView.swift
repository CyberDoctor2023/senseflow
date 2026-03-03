//
//  APIRequestInspectorView.swift
//  SenseFlow
//
//  Created on 2026-02-26.
//  展示最后一次 API 请求的详细信息
//

import SwiftUI
import AppKit

/// API 请求检查器视图
struct APIRequestInspectorView: View {
    @ObservedObject private var recorder: InMemoryAPIRequestRecorder
    private let inspectionService: APIRequestInspectionService
    @State private var selectedRecordID: UUID?
    @State private var selectedDetail: APIRequestDisplayDetail?

    init(
        recorder: InMemoryAPIRequestRecorder = InMemoryAPIRequestRecorder.shared,
        inspectionService: APIRequestInspectionService = UnifiedAPIRequestInspectionService()
    ) {
        self._recorder = ObservedObject(wrappedValue: recorder)
        self.inspectionService = inspectionService
    }

    private var selectedRecord: APIRequestRecord? {
        if let id = selectedRecordID {
            return recorder.allRecords.first(where: { $0.id == id })
        }
        return recorder.allRecords.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("API HTTP 请求详情")
                .font(.subheadline)
                .fontWeight(.medium)

            if recorder.allRecords.isEmpty {
                Text("暂无记录，请先使用任意 Prompt Tool")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 32)
            } else {
                HStack(alignment: .top, spacing: 12) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(recorder.allRecords, id: \.id) { record in
                                Button {
                                    selectedRecordID = record.id
                                } label: {
                                    HStack {
                                        Text(record.formattedTimestamp)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)

                                        Text(record.toolName)
                                            .font(.caption)
                                            .lineLimit(1)

                                        Spacer()

                                        if record.hasImage {
                                            Text("IMG \(record.imageCount)")
                                                .font(.caption2)
                                                .foregroundStyle(.orange)
                                        }

                                        Text(record.isSuccess ? "OK" : "ERR")
                                            .font(.caption2)
                                            .foregroundStyle(record.isSuccess ? .green : .red)
                                    }
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(selectedRecordID == record.id ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08))
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(width: 300)
                    .frame(maxHeight: 420)

                    Divider()
                        .frame(maxHeight: 420)

                    if let request = selectedRecord {
                        let screenshotPreviews = selectedDetail?.screenshotPreviews ?? []

                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                InfoSection(title: "基本信息") {
                                    InfoRow(label: "时间", value: request.formattedTimestamp)
                                    InfoRow(label: "工具名称", value: request.toolName)
                                    InfoRow(label: "AI 服务", value: request.serviceType)
                                    InfoRow(label: "模型", value: request.modelName)
                                    InfoRow(label: "方法", value: request.httpMethod)
                                    InfoRow(label: "Endpoint", value: request.endpoint)
                                    InfoRow(label: "含图片", value: request.hasImage ? "是" : "否")
                                    InfoRow(label: "图片数量", value: "\(request.imageCount)")
                                    InfoRow(label: "状态", value: request.isSuccess ? "✅ 成功" : "❌ 失败")
                                }

                                if request.hasImage || !screenshotPreviews.isEmpty {
                                    InfoSection(title: "截图预览") {
                                        if screenshotPreviews.isEmpty {
                                            Text("此请求包含图片标记，但未能从请求体中提取可预览截图")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .padding(8)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(Color.secondary.opacity(0.1))
                                                .clipShape(.rect(cornerRadius: 6))
                                        } else {
                                            VStack(alignment: .leading, spacing: 12) {
                                                ForEach(Array(screenshotPreviews.enumerated()), id: \.offset) { _, preview in
                                                    ScreenshotPreviewBlock(preview: preview)
                                                }
                                            }
                                        }
                                    }
                                }

                                InfoSection(title: "System Prompt") {
                                    PromptBlock(text: selectedDetail?.systemPrompt ?? "")
                                }

                                InfoSection(title: "User Prompt") {
                                    PromptBlock(text: selectedDetail?.userPrompt ?? "")
                                }

                                InfoSection(title: "AI 回复") {
                                    PromptBlock(text: selectedDetail?.responseText ?? "")
                                }
                            }
                        }
                        .frame(maxHeight: 420)
                    }
                }

                HStack {
                    Text("共 \(recorder.allRecords.count) 条 HTTP 请求")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("清空") {
                        Task {
                            await recorder.clearAll()
                            selectedRecordID = nil
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .onAppear {
            syncSelection()
            refreshSelectedDetail()
        }
        .onChange(of: recorder.allRecords.count) { _ in
            syncSelection()
            refreshSelectedDetail()
        }
        .onChange(of: selectedRecordID) { _ in
            refreshSelectedDetail()
        }
    }

    private func syncSelection() {
        if selectedRecordID == nil {
            selectedRecordID = recorder.allRecords.first?.id
        } else if let selectedRecordID,
                  !recorder.allRecords.contains(where: { $0.id == selectedRecordID }) {
            self.selectedRecordID = recorder.allRecords.first?.id
        }
    }

    private func refreshSelectedDetail() {
        guard let record = selectedRecord else {
            selectedDetail = nil
            return
        }
        selectedDetail = inspectionService.buildDetail(from: record)
    }
}

/// 信息区块
struct InfoSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            content
        }
    }
}

/// 信息行
struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text("\(label):")
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
}

private struct PromptBlock: View {
    let text: String

    var body: some View {
        Text(text.isEmpty ? "(空)" : text)
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.1))
            .clipShape(.rect(cornerRadius: 6))
    }
}

private struct ScreenshotPreviewBlock: View {
    let preview: APIRequestScreenshotPreview
    @State private var openErrorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(preview.title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            if let image = NSImage(data: preview.data) {
                ZStack(alignment: .bottomTrailing) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 260)
                        .frame(maxWidth: .infinity)
                        .clipShape(.rect(cornerRadius: 8))

                    Text("双击用预览打开")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.62))
                        .foregroundStyle(.white)
                        .clipShape(.rect(cornerRadius: 4))
                        .padding(8)
                }
                .contentShape(.rect)
                .onTapGesture(count: 2) {
                    openInSystemPreview()
                }
            } else {
                Text("图片解码失败")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 6))
            }
        }
        .alert(
            "无法打开图片",
            isPresented: Binding(
                get: { openErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        openErrorMessage = nil
                    }
                }
            )
        ) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(openErrorMessage ?? "未知错误")
        }
    }

    private func openInSystemPreview() {
        let ext = inferredImageExtension(for: preview.data)
        let fileURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("senseflow-api-preview-\(UUID().uuidString).\(ext)")

        do {
            try preview.data.write(to: fileURL, options: .atomic)
        } catch {
            openErrorMessage = "写入临时文件失败：\(error.localizedDescription)"
            return
        }

        guard let previewAppURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Preview") else {
            if !NSWorkspace.shared.open(fileURL) {
                openErrorMessage = "无法启动系统预览"
            }
            return
        }

        NSWorkspace.shared.open(
            [fileURL],
            withApplicationAt: previewAppURL,
            configuration: NSWorkspace.OpenConfiguration()
        ) { _, error in
            if let error {
                openErrorMessage = "打开预览失败：\(error.localizedDescription)"
            }
        }
    }

    private func inferredImageExtension(for data: Data) -> String {
        if data.starts(with: [0xFF, 0xD8, 0xFF]) {
            return "jpg"
        }
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return "png"
        }
        if data.starts(with: [0x47, 0x49, 0x46]) {
            return "gif"
        }
        return "jpg"
    }
}

#Preview {
    APIRequestInspectorView()
        .frame(width: 600, height: 600)
        .padding()
}
