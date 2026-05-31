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
    @Published private(set) var queueSongs: [Song] = []

    let playbackTime = PlaybackTimeState()
    let currentSongState = CurrentSongState()

    private let player = ApplicationMusicPlayer.shared
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "PlayerApp",
        category: "MusicPlayer"
    )
    private var stateCancellable: AnyCancellable?
    private var queueCancellable: AnyCancellable?
    private var playbackTimeCancellable: AnyCancellable?
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

    var upNextSongs: [Song] {
        PlaybackQueueWindow.itemsAfterCurrent(
            in: queueSongs,
            currentIndex: currentSongIndex
        )
    }

    func play(_ song: Song, in queue: [Song]) async {
        do {
            let playbackQueue = makePlaybackQueue(from: queue, startingAt: song)
            setPlaybackQueue(playbackQueue, startingAt: song)
            await Task.yield()
            player.queue = ApplicationMusicPlayer.Queue(for: playbackQueue, startingAt: song)
            subscribeToQueue()
            try await player.play()
            syncPlaybackState()
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
            syncPlaybackState()
            return
        }

        guard currentSong != nil else {
            return
        }

        do {
            try await player.play()
            syncPlaybackState()
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
        await Task.yield()

        do {
            try await player.skipToNextEntry()
        } catch {
            rollbackCurrentSongTransition(transition)
            report("Could not skip to the next track.", error: error)
        }
    }

    func skipToPreviousSong() async {
        let transition = moveCurrentSong(by: -1)
        await Task.yield()

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

    func playFromCurrentQueue(_ song: Song) async {
        await play(song, in: queueSongs)
    }

    func clearError() {
        errorMessage = nil
    }

    private func subscribeToPlayerState() {
        stateCancellable = player.state.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.syncPlaybackStateAfterPublishedChange()
            }
    }

    private func subscribeToQueue() {
        queueCancellable = player.queue.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.syncQueueStateAfterPublishedChange()
            }
    }

    private func subscribeToPlaybackTime() {
        playbackTimeCancellable = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.syncPlaybackTime()
            }
    }

    private func syncPlaybackStateAfterPublishedChange() {
        Task { @MainActor [weak self] in
            await Task.yield()
            self?.syncPlaybackState()
        }
    }

    private func syncQueueStateAfterPublishedChange() {
        Task { @MainActor [weak self] in
            await Task.yield()
            self?.syncQueueState()
        }
    }

    private func syncPlayerState() {
        syncPlaybackState()
        syncQueueState()
    }

    private func syncPlaybackState() {
        updatePlaybackStatus(player.state.playbackStatus)
        syncPlaybackTime()
    }

    private func syncQueueState() {
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

        guard let songIndex = queueSongs.firstIndex(where: { $0.id == song.id }) else {
            updateCurrentSong(song)
            return
        }

        currentSongIndex = songIndex
        updateCurrentSong(queueSongs[songIndex])
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
        currentSongState.update(to: song.id)
    }

    private func setPlaybackQueue(_ queue: [Song], startingAt song: Song) {
        queueSongs = queue
        currentSongIndex = queue.firstIndex(where: { $0.id == song.id })
        lastObservedQueueEntryID = nil
        expectedQueueSongID = song.id
        updateCurrentSong(song)
        playbackTime.update(to: 0)
    }

    private func makePlaybackQueue(from queue: [Song], startingAt song: Song) -> [Song] {
        guard let songIndex = queue.firstIndex(where: { $0.id == song.id }) else {
            return [song]
        }

        // Sending a large library to MusicKit delays initial playback. Keep a
        // generous local window so normal previous and next navigation stays fast.
        return PlaybackQueueWindow.items(from: queue, startingAt: songIndex)
    }

    private func moveCurrentSong(
        by offset: Int
    ) -> (previousIndex: Int, destinationIndex: Int)? {
        guard let currentSongIndex else {
            return nil
        }

        let previousIndex = currentSongIndex
        let destinationIndex = currentSongIndex + offset
        guard queueSongs.indices.contains(destinationIndex) else {
            return nil
        }

        selectPlaybackQueueSong(at: destinationIndex)

        return (previousIndex, destinationIndex)
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
        guard queueSongs.indices.contains(index) else {
            return
        }

        let song = queueSongs[index]
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
