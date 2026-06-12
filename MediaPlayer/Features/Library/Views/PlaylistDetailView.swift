//
//  PlaylistDetailView.swift
//  MediaPlayer
//
//  Created by Codex on 01.06.2026.
//

import MusicKit
import SwiftUI

struct PlaylistDetailView: View {
    let playlist: Playlist
    let currentSongState: CurrentSongState
    let onPlay: (Song, [Song]) -> Void

    @StateObject private var viewModel: PlaylistDetailViewModel

    init(
        playlist: Playlist,
        currentSongState: CurrentSongState,
        onPlay: @escaping (Song, [Song]) -> Void
    ) {
        self.playlist = playlist
        self.currentSongState = currentSongState
        self.onPlay = onPlay
        _viewModel = StateObject(
            wrappedValue: PlaylistDetailViewModel(playlist: playlist)
        )
    }

    var body: some View {
        content
            .navigationTitle(playlist.name)
            .task {
                await viewModel.load()
            }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading, viewModel.songs.isEmpty {
            ProgressView("Loading playlist...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage = viewModel.errorMessage {
            ContentUnavailableView {
                Label("Could Not Load Playlist", systemImage: "exclamationmark.triangle")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Try Again") {
                    Task {
                        await viewModel.reload()
                    }
                }
            }
        } else if viewModel.songs.isEmpty {
            ContentUnavailableView(
                "No Songs in This Playlist",
                systemImage: "music.note.list",
                description: Text("This player currently shows songs from your playlists.")
            )
        } else {
            SongListView(
                songs: viewModel.songs,
                queue: viewModel.songs,
                currentSongState: currentSongState,
                isLoading: viewModel.isLoading,
                onPlay: onPlay
            )
        }
    }
}
