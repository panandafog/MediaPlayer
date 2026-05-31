//
//  ContentView.swift
//  MediaPlayer
//
//  Created by Andrey Pantyuhin on 31.05.2026.
//

import MusicKit
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var library = MusicLibraryViewModel()
    @StateObject private var player = MusicPlayerViewModel()

    var body: some View {
        NavigationStack {
            MusicLibraryView(
                library: library,
                currentSong: player.currentSong,
                onPlay: play
            )
            .navigationTitle("Music")
            .searchable(text: $library.searchText, prompt: "Track, album, or artist")
            .toolbar {
                if library.authorizationStatus == .authorized, library.section == .songs {
                    MusicLibrarySortMenu(selection: $library.sortOption)
                }

                if library.authorizationStatus == .authorized {
                    Button {
                        Task {
                            await library.loadSongs()
                        }
                    } label: {
                        Label("Refresh Library", systemImage: "arrow.clockwise")
                    }
                    .disabled(library.isLoading)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let song = player.currentSong {
                NowPlayingBar(
                    song: song,
                    isPlaying: player.isPlaying,
                    playbackTime: player.playbackTime,
                    onPrevious: {
                        Task {
                            await player.skipToPreviousSong()
                        }
                    },
                    onTogglePlayback: {
                        Task {
                            await player.togglePlayback(queue: library.sortedSongs)
                        }
                    },
                    onNext: {
                        Task {
                            await player.skipToNextSong()
                        }
                    },
                    onSeek: player.seek
                )
            }
        }
        .task {
            await library.loadIfAuthorized()
        }
        .onChange(of: scenePhase) {
            guard scenePhase == .active else {
                return
            }

            Task {
                await library.loadIfAuthorized()
            }
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        clearErrors()
                    }
                }
            )
        ) {
            Button("OK", action: clearErrors)
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var errorMessage: String? {
        player.errorMessage ?? library.errorMessage
    }

    private func play(_ song: Song, in queue: [Song]) {
        Task {
            await player.play(song, in: queue)
        }
    }

    private func clearErrors() {
        player.clearError()
        library.clearError()
    }
}

#Preview {
    ContentView()
}
