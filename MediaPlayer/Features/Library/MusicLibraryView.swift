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
    let currentSongState: CurrentSongState
    let onPlay: (Song, [Song]) -> Void

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
        } else {
            sectionContent
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch library.section {
        case .songs:
            if library.filteredSongs.isEmpty {
                noMatchesView
            } else {
                SongListView(
                    songs: library.filteredSongs,
                    queue: library.sortedSongs,
                    currentSongState: currentSongState,
                    isLoading: library.isLoading,
                    onPlay: onPlay
                )
            }
        case .artists:
            if library.filteredArtists.isEmpty {
                noMatchesView
            } else {
                List {
                    ForEach(library.filteredArtists) { artist in
                        NavigationLink {
                            ArtistDetailView(
                                artist: artist,
                                currentSongState: currentSongState,
                                onPlay: onPlay
                            )
                        } label: {
                            ArtistRow(artist: artist)
                        }
                    }

                    loadingFooter
                }
                .listStyle(.plain)
            }
        case .albums:
            if library.filteredAlbums.isEmpty {
                noMatchesView
            } else {
                List {
                    ForEach(library.filteredAlbums) { album in
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

                    loadingFooter
                }
                .listStyle(.plain)
            }
        }
    }

    private var noMatchesView: some View {
        ContentUnavailableView(
            "No Matching Items",
            systemImage: "magnifyingglass",
            description: Text("Try a different song, album, or artist.")
        )
    }

    @ViewBuilder
    private var loadingFooter: some View {
        if library.isLoading {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
        }
    }
}
