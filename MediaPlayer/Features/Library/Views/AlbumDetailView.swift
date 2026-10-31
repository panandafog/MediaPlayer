//
//  AlbumDetailView.swift
//  MediaPlayer
//
//

import MusicKit
import SwiftUI

struct AlbumDetailView: View {
#if os(macOS)
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var tagEditor: TagEditorModel
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
                    tagEditor.open(.album(title: album.title, artist: album.artistName))
                    openWindow(id: TagEditorModel.windowID)
                }
            }
        }
#endif
    }
}
