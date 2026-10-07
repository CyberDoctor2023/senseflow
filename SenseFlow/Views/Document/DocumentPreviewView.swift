import SwiftUI
import AppKit

/// A preview surface. Clicking text enters editing without document-tool chrome.
struct DocumentPreviewView: View {
    @Bindable var session: DocumentPreviewCoordinator
    var body: some View {
        VStack(spacing: 0) {
            if session.recoveredDraft != nil {
                HStack(spacing: 12) {
                    Text("有未保存为记录的草稿").font(.pingFang(.caption))
                    Spacer()
                    Button("继续编辑") { session.continueDraft() }
                    Button("原文") { session.viewOriginal() }
                    Button("删除草稿") { session.deleteRecoveredDraft() }
                }.padding(.horizontal, 20).padding(.bottom, 8).buttonStyle(.borderless)
            }
            if !session.isEditing {
                HStack {
                    Button("编辑") { session.beginEditing() }
                        .buttonStyle(.borderless)
                        .onboardingTarget(.edit, radius: 8)
                    Spacer()
                }.padding(.horizontal, 20).padding(.bottom, 6)
            }
            NativeDocumentEditor(session: session)
            if session.isEditing || session.errorMessage != nil {
                HStack(spacing: 12) {
                    Text(session.errorMessage ?? session.status).font(.pingFang(.caption))
                        .foregroundStyle(session.errorMessage == nil ? Color.secondary : Color.red).lineLimit(2)
                    Spacer(minLength: 8)
                    if session.isEditing {
                        Button("复制") { session.copyAll() }.compatibleButtonStyle()
                        Button("保存为新记录") { session.save() }.compatibleButtonStyle(prominent: true)
                            .onboardingTarget(.save, radius: 10)
                    }
                    if session.errorMessage != nil {
                        Button("重试") { session.retryCheckpoint() }.buttonStyle(.borderless)
                    }
                }.padding(.horizontal, 20).padding(.vertical, 12)
            }
        }
        .environment(\.appearsActive, true)
    }
}
