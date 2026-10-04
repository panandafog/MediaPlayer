//
//  AlbumDetailView.swift
//  MediaPlayer
//
//

import MusicKit
import SwiftUI

struct AlbumDetailView: View {
#if os(macOS)
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingEditor = false
    @State private var didSaveMetadata = false
#endif
    let album: LibraryAlbum
    let currentSongState: CurrentSongState
    let onPlay: (Song, [Song]) -> Void

    var body: some View {
        SongListView(
            songs: album.songs,
            queue: album.songs,
            context: .album,
            currentSongState: currentSongState,
            onPlay: onPlay
        )
        .navigationTitle(album.title)
#if os(macOS)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit Album", systemImage: "pencil") {
                    isShowingEditor = true
                }
            }
        }
        .sheet(isPresented: $isShowingEditor, onDismiss: {
            if didSaveMetadata { dismiss() }
        }) {
            LibraryGroupMetadataEditorView(target: .album(album)) {
                didSaveMetadata = true
            }
        }
#endif
    }
}
