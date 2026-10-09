import SwiftUI

/// One scrolling surface and a readable content width for everyday preferences.
struct SettingsFormContainer<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) { content }
                .frame(maxWidth: 640, alignment: .leading)
                .padding(.horizontal, 28).padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

/// Consistent grouping; page content owns bindings and actions.
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.pingFang(size: 12, weight: .semibold))
                .foregroundStyle(.secondary).padding(.horizontal, 4)
            VStack(alignment: .leading, spacing: 12) { content }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor), in: .rect(cornerRadius: 10))
        }
    }
}

/// Aligns switches to one trailing column, independent of label length.
struct SettingsToggle: View {
    let title: String
    @Binding var isOn: Bool
    var detail: String? = nil
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                if let detail { Text(detail).font(.pingFang(.caption)).foregroundStyle(.secondary) }
            }.frame(maxWidth: .infinity, alignment: .leading)
            Toggle(title, isOn: $isOn).labelsHidden().toggleStyle(.switch)
                .accessibilityLabel(title)
        }
    }
}
