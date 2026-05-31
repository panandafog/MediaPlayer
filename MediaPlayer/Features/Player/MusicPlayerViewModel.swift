//
//  MusicPlayerViewModel.swift
//  MediaPlayer
//
//  Created by Codex on 31.05.2026.
//

import Combine
import Foundation
import MusicKit
import OSLog

@MainActor
final class MusicPlayerViewModel: ObservableObject {
    @Published private(set) var currentSong: Song?
    @Published private(set) var playbackStatus: MusicPlayer.PlaybackStatus = .stopped
    @Published private(set) var errorMessage: String?

    let playbackTime = PlaybackTimeState()

    private let player = ApplicationMusicPlayer.shared
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "PlayerApp",
        category: "MusicPlayer"
    )
    private var stateCancellable: AnyCancellable?
    private var queueCancellable: AnyCancellable?
    private var playbackTimeCancellable: AnyCancellable?
    private var playbackQueue: [Song] = []
    private var currentSongIndex: Int?
    private var lastObservedQueueEntryID: String?
    private var expectedQueueSongID: MusicItemID?

    init() {
        subscribeToPlayerState()
        subscribeToQueue()
        subscribeToPlaybackTime()
        syncPlayerState()
    }

    var isPlaying: Bool {
        playbackStatus == .playing
    }

    func play(_ song: Song, in queue: [Song]) async {
        do {
            setPlaybackQueue(queue, startingAt: song)
            player.queue = ApplicationMusicPlayer.Queue(for: queue, startingAt: song)
            subscribeToQueue()
            try await player.play()
            syncPlayerState()
        } catch {
            await reportPlaybackErrorUnlessPlaying(error, expectedSong: song)
        }
    }

    func togglePlayback(queue: [Song]) async {
        if currentSong == nil, let firstSong = queue.first {
            await play(firstSong, in: queue)
            return
        }

        await togglePlayback()
    }

    func togglePlayback() async {
        if isPlaying {
            player.pause()
            syncPlayerState()
            return
        }

        guard currentSong != nil else {
            return
        }

        do {
            try await player.play()
            syncPlayerState()
        } catch {
            guard let currentSong else {
                report("Could not resume playback.", error: error)
                return
            }

            await reportPlaybackErrorUnlessPlaying(error, expectedSong: currentSong)
        }
    }

    func skipToNextSong() async {
        let transition = moveCurrentSong(by: 1)

        do {
            try await player.skipToNextEntry()
        } catch {
            rollbackCurrentSongTransition(transition)
            report("Could not skip to the next track.", error: error)
        }
    }

    func skipToPreviousSong() async {
        let transition = moveCurrentSong(by: -1)

        do {
            try await player.skipToPreviousEntry()
        } catch {
            rollbackCurrentSongTransition(transition)
            report("Could not skip to the previous track.", error: error)
        }
    }

    func seek(to time: TimeInterval) {
        let normalizedTime = PlaybackProgress.normalizedTime(
            time,
            duration: currentSong?.duration
        )
        player.playbackTime = normalizedTime
        playbackTime.update(to: normalizedTime)
    }

    func clearError() {
        errorMessage = nil
    }

    private func subscribeToPlayerState() {
        stateCancellable = player.state.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.syncAfterPublishedChange()
            }
    }

    private func subscribeToQueue() {
        queueCancellable = player.queue.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.syncAfterPublishedChange()
            }
    }

    private func subscribeToPlaybackTime() {
        playbackTimeCancellable = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.syncPlayerState()
            }
    }

    private func syncAfterPublishedChange() {
        Task { @MainActor [weak self] in
            await Task.yield()
            self?.syncPlayerState()
        }
    }

    private func syncPlayerState() {
        updatePlaybackStatus(player.state.playbackStatus)
        syncPlaybackTime()
        syncCurrentSongFromPlayerQueue()
    }

    private func syncCurrentSongFromPlayerQueue() {
        guard let entry = player.queue.currentEntry,
              case let .song(song) = entry.item,
              entry.id != lastObservedQueueEntryID else {
            return
        }

        lastObservedQueueEntryID = entry.id

        if let expectedQueueSongID {
            if song.id == expectedQueueSongID {
                self.expectedQueueSongID = nil
            }

            return
        }

        guard let songIndex = playbackQueue.firstIndex(where: { $0.id == song.id }) else {
            updateCurrentSong(song)
            return
        }

        currentSongIndex = songIndex
        updateCurrentSong(playbackQueue[songIndex])
        playbackTime.update(to: 0)
    }

    private func syncPlaybackTime() {
        playbackTime.update(
            to: PlaybackProgress.normalizedTime(
                player.playbackTime,
                duration: currentSong?.duration
            )
        )
    }

    private func updatePlaybackStatus(_ playbackStatus: MusicPlayer.PlaybackStatus) {
        guard self.playbackStatus != playbackStatus else {
            return
        }

        self.playbackStatus = playbackStatus
    }

    private func updateCurrentSong(_ song: Song) {
        guard currentSong?.id != song.id else {
            return
        }

        currentSong = song
    }

    private func setPlaybackQueue(_ queue: [Song], startingAt song: Song) {
        playbackQueue = queue
        currentSongIndex = queue.firstIndex(where: { $0.id == song.id })
        lastObservedQueueEntryID = nil
        expectedQueueSongID = song.id
        updateCurrentSong(song)
        playbackTime.update(to: 0)
    }

    private func moveCurrentSong(
        by offset: Int
    ) -> (previousIndex: Int, destinationIndex: Int)? {
        guard let currentSongIndex else {
            return nil
        }

        let destinationIndex = currentSongIndex + offset
        guard playbackQueue.indices.contains(destinationIndex) else {
            return nil
        }

        selectPlaybackQueueSong(at: destinationIndex)

        return (currentSongIndex, destinationIndex)
    }

    private func rollbackCurrentSongTransition(
        _ transition: (previousIndex: Int, destinationIndex: Int)?
    ) {
        guard let transition,
              currentSongIndex == transition.destinationIndex else {
            return
        }

        selectPlaybackQueueSong(at: transition.previousIndex)
    }

    private func selectPlaybackQueueSong(at index: Int) {
        guard playbackQueue.indices.contains(index) else {
            return
        }

        let song = playbackQueue[index]
        currentSongIndex = index
        expectedQueueSongID = song.id
        updateCurrentSong(song)
        playbackTime.update(to: 0)
    }

    private func reportPlaybackErrorUnlessPlaying(_ error: Error, expectedSong: Song) async {
        // MusicKit on macOS can report a queue interruption after playback has
        // already started. Only surface the error if the requested song did not win.
        for attempt in 0..<5 {
            syncPlayerState()

            if playbackStatus == .playing,
               case let .song(song) = player.queue.currentEntry?.item,
               song.id == expectedSong.id {
                return
            }

            if attempt < 4 {
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
        }

        report("Could not start playback.", error: error)
    }

    private func report(_ message: String, error: Error) {
        logger.error("\(message, privacy: .public) \(error.localizedDescription, privacy: .public)")
        errorMessage = message
    }
}
