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
    private let restorationStore: PlaybackRestorationStore
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "PlayerApp",
        category: "MusicPlayer"
    )
    private var stateCancellable: AnyCancellable?
    private var queueCancellable: AnyCancellable?
    private var playbackTimeCancellable: AnyCancellable?
    private var playerStateRefreshTask: Task<Void, Never>?
    private var currentSongIndex: Int?
    private var songIDsByQueueEntryID: [String: MusicItemID] = [:]
    private var didAttemptPlaybackRestoration = false
    private var lastPersistedSongID: MusicItemID?
    private var lastPersistedPlaybackTime: TimeInterval?

    init(restorationStore: PlaybackRestorationStore? = nil) {
        self.restorationStore = restorationStore ?? PlaybackRestorationStore()
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
            installPlaybackQueue(playbackQueue, startingAt: song)
            try await player.play()
            schedulePlayerStateRefresh()
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
            savePlaybackPosition()
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
        do {
            try await player.skipToNextEntry()
            schedulePlayerStateRefresh()
        } catch {
            report("Could not skip to the next track.", error: error)
        }
    }

    func skipToPreviousSong() async {
        do {
            try await player.skipToPreviousEntry()
            schedulePlayerStateRefresh()
        } catch {
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
        persistPlaybackSnapshot(force: true)
    }

    func playFromCurrentQueue(_ song: Song) async {
        await play(song, in: queueSongs)
    }

    func refreshPlaybackState() {
        subscribeToQueue()
        rebuildQueueEntrySongMapping()
        schedulePlayerStateRefresh()
    }

    func savePlaybackPosition() {
        syncPlayerState()
        persistPlaybackSnapshot(force: true)
    }

    func restorePlaybackIfNeeded(from librarySongs: [Song]) {
        syncPlayerState()

        guard !didAttemptPlaybackRestoration,
              currentSong == nil,
              !librarySongs.isEmpty,
              let snapshot = restorationStore.load() else {
            return
        }

        didAttemptPlaybackRestoration = true

        let songsByID = librarySongs.reduce(into: [MusicItemID: Song]()) { songsByID, song in
            songsByID[song.id] = song
        }
        guard let currentSong = songsByID[snapshot.currentSongID] else {
            restorationStore.clear()
            return
        }

        var restoredQueue = snapshot.queueSongIDs.compactMap { songsByID[$0] }
        if !restoredQueue.contains(where: { $0.id == currentSong.id }) {
            restoredQueue = [currentSong]
        }

        installPlaybackQueue(restoredQueue, startingAt: currentSong)
        seek(to: snapshot.playbackTime)
        syncPlayerState()
    }

    func clearError() {
        errorMessage = nil
    }

    private func subscribeToPlayerState() {
        stateCancellable = player.state.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.schedulePlayerStateRefresh()
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
                self?.syncPlayerState()
            }
    }

    private func syncQueueStateAfterPublishedChange() {
        schedulePlayerStateRefresh()
    }

    private func schedulePlayerStateRefresh() {
        playerStateRefreshTask?.cancel()
        playerStateRefreshTask = Task { @MainActor [weak self] in
            for delay in [UInt64(0), 100_000_000, 300_000_000, 750_000_000] {
                if delay > 0 {
                    do {
                        try await Task.sleep(nanoseconds: delay)
                    } catch {
                        return
                    }
                }

                guard let self else {
                    return
                }

                syncPlayerState()
            }
        }
    }

    private func syncPlayerState() {
        syncQueueState()
        syncPlaybackState()
    }

    private func syncPlaybackState() {
        updatePlaybackStatus(player.state.playbackStatus)
        syncPlaybackTime()
    }

    private func syncQueueState() {
        syncCurrentSongFromPlayerQueue()
    }

    private func syncCurrentSongFromPlayerQueue() {
        guard let entry = player.queue.currentEntry else {
            return
        }

        if songIDsByQueueEntryID[entry.id] == nil {
            rebuildQueueEntrySongMapping()
        }

        if let songID = songIDsByQueueEntryID[entry.id],
           let songIndex = queueSongs.firstIndex(where: { $0.id == songID }) {
            selectCurrentSongFromQueue(at: songIndex)
            return
        }

        if player.queue.entries.count == queueSongs.count,
           let entryIndex = player.queue.entries.firstIndex(of: entry),
           queueSongs.indices.contains(entryIndex) {
            selectCurrentSongFromQueue(at: entryIndex)
            return
        }

        guard case let .song(song) = entry.item else {
            return
        }

        if let songIndex = queueSongs.firstIndex(where: { $0.id == song.id }) {
            selectCurrentSongFromQueue(at: songIndex)
            return
        }

        let didCurrentSongChange = currentSong?.id != song.id
        currentSongIndex = nil
        updateCurrentSong(song)
        if didCurrentSongChange {
            playbackTime.update(to: 0)
        }
    }

    private func selectCurrentSongFromQueue(at index: Int) {
        guard queueSongs.indices.contains(index) else {
            return
        }

        let song = queueSongs[index]
        let didCurrentSongChange = currentSong?.id != song.id
        currentSongIndex = index
        updateCurrentSong(song)
        if didCurrentSongChange {
            playbackTime.update(to: 0)
        }
    }

    private func syncPlaybackTime() {
        let normalizedTime = PlaybackProgress.normalizedTime(
            player.playbackTime,
            duration: currentSong?.duration
        )
        playbackTime.update(to: normalizedTime)
        persistPlaybackSnapshot()
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
        updateCurrentSong(song)
        playbackTime.update(to: 0)
        persistPlaybackSnapshot(force: true)
    }

    private func installPlaybackQueue(_ songs: [Song], startingAt song: Song) {
        let playbackQueue = ApplicationMusicPlayer.Queue(for: songs, startingAt: song)
        player.queue = playbackQueue
        setPlaybackQueue(songs, startingAt: song)
        rebuildQueueEntrySongMapping()
        subscribeToQueue()
    }

    private func rebuildQueueEntrySongMapping() {
        guard player.queue.entries.count == queueSongs.count else {
            return
        }

        songIDsByQueueEntryID = zip(player.queue.entries, queueSongs).reduce(into: [:]) {
            entryIDs, pair in
            entryIDs[pair.0.id] = pair.1.id
        }
    }

    private func makePlaybackQueue(from queue: [Song], startingAt song: Song) -> [Song] {
        guard let songIndex = queue.firstIndex(where: { $0.id == song.id }) else {
            return [song]
        }

        // Sending a large library to MusicKit delays initial playback. Keep a
        // generous local window so normal previous and next navigation stays fast.
        return PlaybackQueueWindow.items(from: queue, startingAt: songIndex)
    }

    private func persistPlaybackSnapshot(force: Bool = false) {
        guard let currentSong else {
            return
        }

        let normalizedTime = PlaybackProgress.normalizedTime(
            playbackTime.value,
            duration: currentSong.duration
        )
        let hasMeaningfulProgressChange = lastPersistedPlaybackTime.map {
            abs($0 - normalizedTime) >= 2
        } ?? true

        guard force
                || lastPersistedSongID != currentSong.id
                || hasMeaningfulProgressChange else {
            return
        }

        var queueSongIDs = queueSongs.map(\.id)
        if !queueSongIDs.contains(currentSong.id) {
            queueSongIDs = [currentSong.id]
        }

        restorationStore.save(
            PlaybackRestorationSnapshot(
                queueSongIDs: queueSongIDs,
                currentSongID: currentSong.id,
                playbackTime: normalizedTime
            )
        )
        lastPersistedSongID = currentSong.id
        lastPersistedPlaybackTime = normalizedTime
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
