//
//  PlayerSettingsView.swift
//  MediaPlayer
//

import SwiftUI

struct PlayerSettingsView: View {
    @EnvironmentObject private var artworkAccentTheme: ArtworkAccentTheme
    @State private var isSeparatorFieldFocused = false
    @AppStorage(PlayerSettingsKey.resumesPlaybackOnLaunch)
    private var resumesPlaybackOnLaunch = false
    @AppStorage(PlayerSettingsKey.usesArtworkAccentColor)
    private var usesArtworkAccentColor = true
    @AppStorage(PlayerSettingsKey.smartArtistSeparatorCharacters)
    private var smartArtistSeparatorCharacters =
        SmartArtistGroupingSettings.defaultSeparatorCharacters
    @AppStorage(PlayerSettingsKey.usesSmartArtistGrouping)
    private var usesSmartArtistGrouping = false
    @AppStorage(PlayerSettingsKey.songListFieldOrder)
    private var storedSongListFieldOrder = "releaseYear,genre,playCount,dateAdded,lastPlayed"
    @AppStorage(PlayerSettingsKey.songListEnabledFields)
    private var storedEnabledSongListFields = "releaseYear,genre"
    @AppStorage(PlayerSettingsKey.songListShowsAlbum)
    private var songListShowsAlbum = true
    @AppStorage(PlayerSettingsKey.songListShowsDuration)
    private var songListShowsDuration = true
    @AppStorage(PlayerSettingsKey.songListShowsInfoButton)
    private var songListShowsInfoButton = true
#if os(iOS)
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isIOSSeparatorFieldFocused: Bool
    @AppStorage(PlayerSettingsKey.searchBarPosition) private var searchBarPosition =
        SearchBarPosition.top.rawValue
#elseif os(macOS)
    @AppStorage(PlayerSettingsKey.usesLiquidGlassInPlayerWindow)
    private var usesLiquidGlassInPlayerWindow = true
    @AppStorage(PlayerSettingsKey.usesArtworkDockIcon)
    private var usesArtworkDockIcon = true
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
            Section {
                Toggle(
                    "Start Playback on Launch from Last Position",
                    isOn: $resumesPlaybackOnLaunch
                )
            } header: {
                Text("Playback")
            } footer: {
                Text(
                    "The current track and position are saved automatically. "
                        + "When this is off, the last track is restored on pause."
                )
            }

            Section("Appearance") {
                Toggle(
                    "Match App Accent to Artwork",
                    isOn: $usesArtworkAccentColor
                )
                Text(
                    "Uses the current track’s artwork for accent colors throughout the app. "
                        + "In the full player, only the progress bar and Play/Pause button are colored."
                )
                    .font(.footnote)
                    .foregroundStyle(.secondary)

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
                    "Match Dock Icon to Artwork",
                    isOn: $usesArtworkDockIcon
                )
                Text(
                    "Changes the icon in the Dock while the app is running. "
                        + "The icon in Finder and Launchpad stays unchanged."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)

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

                        separatorCharactersField

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

            Section {
                Toggle("Album", isOn: $songListShowsAlbum)
                Toggle("Duration", isOn: $songListShowsDuration)
                Toggle("Track Info Button", isOn: $songListShowsInfoButton)

                Text("Additional Metadata")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(orderedSongListFields) { field in
                    HStack(spacing: Layout.fieldControlSpacing) {
                        Text(field.title)
                        Spacer()

                        Button {
                            moveSongListField(field, by: -1)
                        } label: {
                            Image(systemName: "arrow.up")
                        }
                        .disabled(orderedSongListFields.first == field)
                        .accessibilityLabel("Move \(field.title) earlier")

                        Button {
                            moveSongListField(field, by: 1)
                        } label: {
                            Image(systemName: "arrow.down")
                        }
                        .disabled(orderedSongListFields.last == field)
                        .accessibilityLabel("Move \(field.title) later")

                        Toggle(field.title, isOn: songListFieldBinding(for: field))
                            .labelsHidden()
                    }
                    .buttonStyle(.borderless)
                }

                Button("Reset Track List Fields") {
                    storedSongListFieldOrder = SongListField.storageValue(
                        SongListField.defaultOrder
                    )
                    storedEnabledSongListFields = SongListField.storageValue(
                        SongListField.defaultEnabled
                    )
                    songListShowsAlbum = true
                    songListShowsDuration = true
                    songListShowsInfoButton = true
                }
            } header: {
                Text("Track List Fields")
            } footer: {
                Text(
                    "Album, duration, and the info button can be hidden independently. "
                        + "Other enabled fields appear below the title on narrow lists "
                        + "and as columns on wide lists. Track info remains available "
                        + "from the row’s context menu."
                )
            }
        }
        .formStyle(.grouped)
    }

    private var separatorCharactersField: some View {
        Group {
#if os(macOS)
            MacAccentTextField(
                placeholder: "Characters",
                text: separatorCharactersBinding,
                accentColor: artworkAccentTheme.color,
                isFocused: $isSeparatorFieldFocused
            )
#else
            TextField("Characters", text: separatorCharactersBinding)
                .textFieldStyle(.plain)
                .tint(artworkAccentTheme.color ?? .accentColor)
                .focused($isIOSSeparatorFieldFocused)
                .onChange(of: isIOSSeparatorFieldFocused, initial: true) {
                    isSeparatorFieldFocused = isIOSSeparatorFieldFocused
                }
#endif
        }
        .font(.body.monospaced())
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(.background, in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(
                    isSeparatorFieldFocused
                        ? (artworkAccentTheme.color ?? .accentColor)
                        : Color.secondary.opacity(0.4),
                    lineWidth: isSeparatorFieldFocused ? 2 : 1
                )
        }
    }

    private var separatorCharactersBinding: Binding<String> {
        Binding(
            get: { smartArtistSeparatorCharacters },
            set: { newValue in
                smartArtistSeparatorCharacters =
                    SmartArtistGroupingSettings.normalizedSeparatorCharacters(newValue)
            }
        )
    }

    private var orderedSongListFields: [SongListField] {
        SongListField.order(from: storedSongListFieldOrder)
    }

    private func songListFieldBinding(for field: SongListField) -> Binding<Bool> {
        Binding(
            get: {
                SongListField.enabled(from: storedEnabledSongListFields).contains(field)
            },
            set: { isEnabled in
                var enabled = SongListField.enabled(from: storedEnabledSongListFields)
                if isEnabled {
                    enabled.insert(field)
                } else {
                    enabled.remove(field)
                }
                storedEnabledSongListFields = SongListField.storageValue(
                    orderedSongListFields.filter { enabled.contains($0) }
                )
            }
        )
    }

    private func moveSongListField(_ field: SongListField, by offset: Int) {
        var order = orderedSongListFields
        guard let index = order.firstIndex(of: field),
              order.indices.contains(index + offset) else {
            return
        }
        order.swapAt(index, index + offset)
        storedSongListFieldOrder = SongListField.storageValue(order)
    }
}

private enum Layout {
    static let padding: CGFloat = 20
    static let settingSpacing: CGFloat = 8
    static let fieldControlSpacing: CGFloat = 12
    static let width: CGFloat = 540
    static let height: CGFloat = 680
}

#Preview {
    PlayerSettingsView()
        .environmentObject(ArtworkAccentTheme())
}
