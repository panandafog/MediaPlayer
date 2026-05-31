//
//  MusicLibraryView.swift
//  MediaPlayer
//
//  Created by Codex on 31.05.2026.
//

import MusicKit
import SwiftUI

struct MusicLibraryView: View {
    @ObservedObject var library: MusicLibraryViewModel
    let currentSong: Song?
    let onPlay: (Song) -> Void

    var body: some View {
        libraryContent
    }

    @ViewBuilder
    private var libraryContent: some View {
        switch library.authorizationStatus {
        case .notDetermined:
            PermissionView {
                Task {
                    await library.requestAuthorization()
                }
            }
        case .denied:
            AccessUnavailableView(
                title: "Music Library Access Denied",
                message: "Allow Music access in Settings under Privacy & Security > Media & Apple Music, then return to the app.",
                actionTitle: "Open Settings",
                action: AppSettingsOpener.open
            )
        case .restricted:
            AccessUnavailableView(
                title: "Music Library Access Restricted",
                message: "System restrictions prevent access to your Music library."
            )
        case .authorized:
            authorizedContent
        @unknown default:
            AccessUnavailableView(
                title: "Music Library Unavailable",
                message: "The app could not determine the Music access status."
            )
        }
    }

    @ViewBuilder
    private var authorizedContent: some View {
        if library.songs.isEmpty, library.isLoading {
            ProgressView("Loading your music library...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if library.songs.isEmpty {
            ContentUnavailableView(
                "Your Music Library Is Empty",
                systemImage: "music.note.list",
                description: Text("Add music in the Music app, then refresh your library.")
            )
        } else if library.filteredSongs.isEmpty {
            ContentUnavailableView(
                "No Matching Tracks",
                systemImage: "magnifyingglass",
                description: Text("Try a different track, album, or artist.")
            )
        } else {
            List {
                ForEach(library.filteredSongs) { song in
                    SongRow(
                        song: song,
                        isCurrent: currentSong?.id == song.id,
                        onPlay: { onPlay(song) }
                    )
                    .equatable()
                }

                if library.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}
