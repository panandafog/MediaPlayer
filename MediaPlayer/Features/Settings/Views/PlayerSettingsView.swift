//
//  PlayerSettingsView.swift
//  MediaPlayer
//

import SwiftUI

struct PlayerSettingsView: View {
#if os(iOS)
    @Environment(\.dismiss) private var dismiss
    @AppStorage(PlayerSettingsKey.searchBarPosition) private var searchBarPosition =
        SearchBarPosition.top.rawValue
#elseif os(macOS)
    @AppStorage(PlayerSettingsKey.usesLiquidGlassInPlayerWindow)
    private var usesLiquidGlassInPlayerWindow = true
#endif

    var body: some View {
#if os(iOS)
        NavigationStack {
            settingsForm
                .navigationTitle("Settings")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
#else
        settingsForm
            .padding(Layout.padding)
            .frame(width: Layout.width, height: Layout.height)
#endif
    }

    private var settingsForm: some View {
        Form {
            Section("Appearance") {
#if os(iOS)
                Picker("Search Position", selection: $searchBarPosition) {
                    ForEach(SearchBarPosition.allCases) { position in
                        Text(position.title)
                            .tag(position.rawValue)
                    }
                }
                .pickerStyle(.segmented)
#elseif os(macOS)
                Toggle(
                    "Use Liquid Glass in Player Window",
                    isOn: $usesLiquidGlassInPlayerWindow
                )
#endif
            }

            Section("Equalizer") {
                EqualizerSettingsView()
            }
        }
        .formStyle(.grouped)
    }
}

private enum Layout {
    static let padding: CGFloat = 20
    static let width: CGFloat = 540
    static let height: CGFloat = 600
}

#Preview {
    PlayerSettingsView()
}
