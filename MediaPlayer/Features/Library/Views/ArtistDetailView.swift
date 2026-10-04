//
//  ArtistDetailView.swift
//  MediaPlayer
//
//

import MusicKit
import SwiftUI

struct ArtistDetailView: View {
#if os(macOS)
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingEditor = false
    @State private var didSaveMetadata = false
#endif
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
                    context: .artist(artist.name),
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
                .avoidsPlayerAccessory()
            }
        }
        .navigationTitle(artist.name)
        .toolbar {
#if os(macOS)
            ToolbarItem(placement: .primaryAction) {
                Button("Edit Artist", systemImage: "pencil") {
                    isShowingEditor = true
                }
            }
#endif
            ToolbarItem(placement: .primaryAction) {
                ArtistLibraryMenu(selection: $section)
            }
        }
#if os(macOS)
        .sheet(isPresented: $isShowingEditor, onDismiss: {
            if didSaveMetadata { dismiss() }
        }) {
            LibraryGroupMetadataEditorView(target: .artist(artist)) {
                didSaveMetadata = true
            }
        }
#endif
    }
}
