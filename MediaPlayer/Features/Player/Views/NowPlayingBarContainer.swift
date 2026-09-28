//
//  NowPlayingBarContainer.swift
//  MediaPlayer
//
//

import MusicKit
import SwiftUI

struct NowPlayingBarContainer: View {
    @ObservedObject var player: MusicPlayerViewModel
    let bottomSafeAreaInset: CGFloat
    let onOpenDetails: () -> Void
    let onOpenArtist: (Song) -> Void
    let onOpenAlbum: (Song) -> Void
    @State private var isShowingQueue = false
    @State private var detailsSong: Song?

    var body: some View {
        Group {
            if let song = player.currentSong {
                NowPlayingBar(
                    song: song,
                    isPlaying: player.isPlaying,
                    playbackMode: player.playbackMode,
                    playbackTime: player.playbackTime,
                    bottomSafeAreaInset: bottomSafeAreaInset,
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
                    onOpenTrackInfo: { detailsSong = $0 },
                    onOpenArtist: onOpenArtist,
                    onOpenAlbum: onOpenAlbum
                )
            }
        }
        .sheet(isPresented: $isShowingQueue) {
            PlaybackQueueView(player: player)
        }
        .sheet(item: $detailsSong) { song in
            TrackDetailsView(song: song)
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
