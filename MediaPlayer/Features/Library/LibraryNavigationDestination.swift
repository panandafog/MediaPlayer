//
//  LibraryNavigationDestination.swift
//  MediaPlayer
//
//  Created by Codex on 12.06.2026.
//

import Combine
import MusicKit
import SwiftUI

enum LibraryNavigationDestination: Hashable {
    case artist(LibraryArtist.ID)
    case album(LibraryAlbum.ID)
}

#if os(macOS)
@MainActor
final class MainWindowNavigation: ObservableObject {
    struct Request: Equatable {
        let id = UUID()
        let destination: LibraryNavigationDestination
    }

    static let windowID = "main-library"

    @Published private(set) var request: Request?

    func open(_ destination: LibraryNavigationDestination) {
        request = Request(destination: destination)
    }

    func consume(_ requestID: UUID) {
        guard request?.id == requestID else {
            return
        }

        request = nil
    }
}
#endif

struct LibraryNavigationDestinationView: View {
    let destination: LibraryNavigationDestination
    @ObservedObject var library: MusicLibraryViewModel
    let currentSongState: CurrentSongState
    let onPlay: (Song, [Song]) -> Void

    @ViewBuilder
    var body: some View {
        switch destination {
        case let .artist(id):
            if let artist = library.artist(id: id) {
                ArtistDetailView(
                    artist: artist,
                    currentSongState: currentSongState,
                    onPlay: onPlay
                )
            } else {
                unavailableView
            }
        case let .album(id):
            if let album = library.album(id: id) {
                AlbumDetailView(
                    album: album,
                    currentSongState: currentSongState,
                    onPlay: onPlay
                )
            } else {
                unavailableView
            }
        }
    }

    private var unavailableView: some View {
        ContentUnavailableView(
            "Item Unavailable",
            systemImage: "music.note",
            description: Text("This item is no longer available in your music library.")
        )
    }
}
