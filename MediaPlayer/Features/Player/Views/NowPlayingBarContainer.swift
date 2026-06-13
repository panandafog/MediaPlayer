//
//  NowPlayingBarContainer.swift
//  MediaPlayer
//
//  Created by Codex on 31.05.2026.
//

import MusicKit
import SwiftUI

struct NowPlayingBarContainer: View {
    @ObservedObject var player: MusicPlayerViewModel
    let onOpenDetails: () -> Void
    let onOpenArtist: (Song) -> Void
    let onOpenAlbum: (Song) -> Void
    @State private var isShowingQueue = false

    var body: some View {
        Group {
            if let song = player.currentSong {
                NowPlayingBar(
                    song: song,
                    isPlaying: player.isPlaying,
                    playbackMode: player.playbackMode,
                    playbackTime: player.playbackTime,
                    onPrevious: {
                        Task {
                            await player.skipToPreviousSong()
                        }
                    },
                    onTogglePlayback: {
                        Task {
                            await player.togglePlayback()
                        }
                    },
                    onNext: {
                        Task {
                            await player.skipToNextSong()
                        }
                    },
                    onSeek: player.seek,
                    onSelectPlaybackMode: player.setPlaybackMode,
                    onShowQueue: {
                        isShowingQueue = true
                    },
                    onOpenDetails: onOpenDetails,
                    onOpenArtist: onOpenArtist,
                    onOpenAlbum: onOpenAlbum
                )
            }
        }
        .sheet(isPresented: $isShowingQueue) {
            PlaybackQueueView(player: player)
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { player.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        player.clearError()
                    }
                }
            )
        ) {
            Button("OK", action: player.clearError)
        } message: {
            Text(player.errorMessage ?? "")
        }
    }
}
