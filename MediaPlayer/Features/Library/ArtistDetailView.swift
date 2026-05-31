//
//  ArtistDetailView.swift
//  MediaPlayer
//
//  Created by Codex on 31.05.2026.
//

import MusicKit
import SwiftUI

struct ArtistDetailView: View {
    let artist: LibraryArtist
    let currentSongState: CurrentSongState
    let onPlay: (Song, [Song]) -> Void

    @State private var section: ArtistLibrarySection = .songs

    var body: some View {
        VStack(spacing: 0) {
            Picker("Artist Section", selection: $section) {
                ForEach(ArtistLibrarySection.allCases) { section in
                    Text(section.title)
                        .tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            switch section {
            case .songs:
                SongListView(
                    songs: artist.songs,
                    queue: artist.songs,
                    currentSongState: currentSongState,
                    onPlay: onPlay
                )
            case .albums:
                List(artist.albums) { album in
                    NavigationLink {
                        AlbumDetailView(
                            album: album,
                            currentSongState: currentSongState,
                            onPlay: onPlay
                        )
                    } label: {
                        AlbumRow(album: album)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(artist.name)
    }
}
