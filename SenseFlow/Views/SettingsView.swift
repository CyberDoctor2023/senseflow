import SwiftUI
import AppKit

/// A quiet, consistent shell around the app's existing preferences.
struct SettingsView: View {
    @Environment(SettingsModel.self) private var model
    @State private var selectedSetting: SettingOption = .general
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 28) {
                HStack(spacing: 10) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable().frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("senseflow").font(.pingFang(size: 18, weight: .semibold))
                        Text("设置").font(.pingFang(size: 10)).foregroundStyle(.secondary)
                    }
                }
                VStack(spacing: 8) {
                    ForEach(SettingOption.allCases) { option in
                        Button { selectedSetting = option } label: {
                            HStack(spacing: 12) {
                                Image(systemName: option.symbolName).font(.pingFang(size: 16)).frame(width: 22)
                                Text(option.title).font(.pingFang(size: 13, weight: selectedSetting == option ? .semibold : .regular))
                                Spacer()

                            }
                            .foregroundStyle(selectedSetting == option ? Color.primary : Color.secondary)
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .background {
                                if selectedSetting == option { RoundedRectangle(cornerRadius: 8).fill(.primary.opacity(0.07)) }
                            }
                            .contentShape(.rect(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selectedSetting == option ? .isSelected : [])
                    }
                }
                Spacer()
                VStack(alignment: .leading, spacing: 5) {
                    Text("版本 \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")")
                        .font(.pingFang(size: 10)).foregroundStyle(.tertiary)
                }
            }
            .padding(24).frame(width: 220)
            .frame(maxHeight: .infinity)
            .background {
                Color(nsColor: .windowBackgroundColor)
                    .ignoresSafeArea(.container, edges: .top)
            }

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 9) {
                    Text(selectedSetting.title).font(.pingFang(size: 22, weight: .semibold))
                }
                .padding(.horizontal, 28).padding(.top, 28).padding(.bottom, 18)
                selectedSetting.viewForPage(model: model)
                    .scrollContentBackground(.hidden)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                Color(nsColor: .windowBackgroundColor)
                    .ignoresSafeArea(.container, edges: .top)
            }
        }
        .toggleStyle(.switch)
        .font(.pingFang(size: 13))
        .animation(.easeInOut(duration: reduceMotion ? 0 : 0.16), value: selectedSetting)
    }
}
