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
        Group {
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
                    NavigationLink(value: LibraryNavigationDestination.album(album.id)) {
                        AlbumRow(album: album)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(artist.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ArtistLibraryMenu(selection: $section)
            }
        }
    }
}
