//
//  SongListView.swift
//  MediaPlayer
//
//

import MusicKit
import SwiftUI

struct SongListView: View {
    @State private var selectedSong: Song?
    @ScaledMetric(relativeTo: .body) private var textScale: CGFloat = 1
    @AppStorage(PlayerSettingsKey.songListFieldOrder)
    private var storedFieldOrder = "releaseYear,genre,playCount,dateAdded,lastPlayed"
    @AppStorage(PlayerSettingsKey.songListEnabledFields)
    private var storedEnabledFields = "releaseYear,genre"
    @AppStorage(PlayerSettingsKey.songListShowsAlbum)
    private var showsAlbum = true
    @AppStorage(PlayerSettingsKey.songListShowsDuration)
    private var showsDuration = true
    @AppStorage(PlayerSettingsKey.songListShowsInfoButton)
    private var showsInfoButton = true

    let songs: [Song]
    let queue: [Song]
    let context: SongListContext
    let currentSongState: CurrentSongState
    let isLoading: Bool
    let onPlay: (Song, [Song]) -> Void

    init(
        songs: [Song],
        queue: [Song],
        context: SongListContext = .library,
        currentSongState: CurrentSongState,
        isLoading: Bool = false,
        onPlay: @escaping (Song, [Song]) -> Void
    ) {
        self.songs = songs
        self.queue = queue
        self.context = context
        self.currentSongState = currentSongState
        self.isLoading = isLoading
        self.onPlay = onPlay
    }

    var body: some View {
        GeometryReader { geometry in
            let enabled = SongListField.enabled(from: storedEnabledFields)
            let orderedFields = SongListField.order(from: storedFieldOrder)
                .filter { enabled.contains($0) }
            let layout = SongListLayout(
                availableWidth: geometry.size.width,
                textScale: textScale,
                context: context,
                orderedFields: orderedFields,
                showsAlbum: showsAlbum,
                showsDuration: showsDuration,
                showsInfoButton: showsInfoButton
            )

            List {
                if layout.density == .expanded {
                    SongListColumnHeader(layout: layout)
                        .listRowSeparator(.hidden)
                        .accessibilityHidden(true)
                }

                ForEach(songs) { song in
                    HStack(spacing: 8) {
                        SongRow(
                            song: song,
                            layout: layout,
                            context: context,
                            currentSongState: currentSongState,
                            onPlay: { onPlay(song, queue) }
                        )
                        .equatable()

                        if layout.showsInfoButton {
                            Button {
                                selectedSong = song
                            } label: {
                                Image(systemName: "info.circle")
                                    .frame(width: 32, height: 44)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Track info: \(song.title)")
                        }
                    }
                    .contextMenu {
                        Button {
                            selectedSong = song
                        } label: {
                            Label("Track Info", systemImage: "info.circle")
                        }
                    }
                }

                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            }
            .listStyle(.plain)
            .avoidsPlayerAccessory()
        }
        .sheet(item: $selectedSong) { song in
            TrackDetailsView(song: song)
        }
    }
}

private struct SongListColumnHeader: View {
    let layout: SongListLayout

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: LibraryRowMetrics.spacing) {
                Color.clear
                    .frame(width: LibraryRowMetrics.artworkSize, height: 1)

                Text("Track")
                    .frame(maxWidth: .infinity, alignment: .leading)

                if layout.showsAlbumColumn {
                    Text("Album")
                        .frame(width: layout.albumColumnWidth, alignment: .leading)
                }

                ForEach(layout.fields) { field in
                    Text(field.title)
                        .frame(width: layout.width(for: field), alignment: .leading)
                }

                Color.clear
                    .frame(width: LibraryRowMetrics.currentSongIndicatorWidth, height: 1)

                if layout.showsDuration {
                    Text("Time")
                        .frame(width: 44, alignment: .trailing)
                }
            }
            .frame(maxWidth: .infinity)

            if layout.showsInfoButton {
                Color.clear
                    .frame(width: 32, height: 1)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
