//
//  PlayerSettingsView.swift
//  MediaPlayer
//

import SwiftUI

struct PlayerSettingsView: View {
    @AppStorage(PlayerSettingsKey.smartArtistSeparatorCharacters)
    private var smartArtistSeparatorCharacters =
        SmartArtistGroupingSettings.defaultSeparatorCharacters
    @AppStorage(PlayerSettingsKey.usesSmartArtistGrouping)
    private var usesSmartArtistGrouping = false
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
                VStack(alignment: .leading, spacing: Layout.settingSpacing) {
                    Text("Search Bar Position")
                        .font(.headline)

                    Picker("Search Bar Position", selection: $searchBarPosition) {
                        ForEach(SearchBarPosition.allCases) { position in
                            Text(position.title)
                                .tag(position.rawValue)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)

                    Text("Choose where the search bar appears in the music library.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
#elseif os(macOS)
                Toggle(
                    "Use Liquid Glass in Player Window",
                    isOn: $usesLiquidGlassInPlayerWindow
                )
#endif
            }

            Section("Music Library") {
                Toggle("Smart Artist Grouping", isOn: $usesSmartArtistGrouping)

                if usesSmartArtistGrouping {
                    VStack(alignment: .leading, spacing: Layout.settingSpacing) {
                        Text("Separator Characters")
                            .font(.headline)

                        TextField(
                            "Characters",
                            text: Binding(
                                get: { smartArtistSeparatorCharacters },
                                set: { newValue in
                                    smartArtistSeparatorCharacters =
                                        SmartArtistGroupingSettings
                                        .normalizedSeparatorCharacters(newValue)
                                }
                            )
                        )
                        .textFieldStyle(.roundedBorder)
                        .font(.body.monospaced())

                        Text(
                            "Each character is used literally. "
                                + "Regular expressions aren’t supported."
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                        Button("Reset Separators") {
                            smartArtistSeparatorCharacters =
                                SmartArtistGroupingSettings.defaultSeparatorCharacters
                        }
                        .disabled(
                            smartArtistSeparatorCharacters
                                == SmartArtistGroupingSettings.defaultSeparatorCharacters
                        )
                    }
                }

                Text(
                    "Separates combined names such as “Artist One; Artist Two” "
                        + "and groups each track under its individual artists."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private enum Layout {
    static let padding: CGFloat = 20
    static let settingSpacing: CGFloat = 8
    static let width: CGFloat = 540
    static let height: CGFloat = 460
}

#Preview {
    PlayerSettingsView()
}
