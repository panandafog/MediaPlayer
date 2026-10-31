//
//  ArtistDetailView.swift
//  MediaPlayer
//
//

import MusicKit
import SwiftUI

struct ArtistDetailView: View {
#if os(macOS)
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var tagEditor: TagEditorModel
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
                    tagEditor.open(.artist(artist.name))
                    openWindow(id: TagEditorModel.windowID)
                }
            }
#endif
            ToolbarItem(placement: .primaryAction) {
                ArtistLibraryMenu(selection: $section)
            }
        }
    }
}
