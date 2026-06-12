//
//  PlaybackRestorationStore.swift
//  MediaPlayer
//

import Foundation
import MusicKit

nonisolated struct PlaybackRestorationSnapshot: Equatable, Sendable {
    let queueSongIDs: [MusicItemID]
    let currentSongID: MusicItemID
    let playbackTime: TimeInterval
}

@MainActor
final class PlaybackRestorationStore {
    private enum Key {
        static let queueSongIDs = "queueSongIDs"
        static let currentSongID = "currentSongID"
        static let playbackTime = "playbackTime"
    }

    private let defaults: UserDefaults
    private let keyPrefix: String

    init(
        defaults: UserDefaults = .standard,
        keyPrefix: String = "playback.restoration"
    ) {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
    }

    func load() -> PlaybackRestorationSnapshot? {
        guard let currentSongID = defaults.string(forKey: key(for: Key.currentSongID)) else {
            return nil
        }

        let storedPlaybackTime = defaults.double(forKey: key(for: Key.playbackTime))
        let playbackTime = storedPlaybackTime.isFinite ? max(storedPlaybackTime, 0) : 0
        let queueSongIDs = defaults
            .stringArray(forKey: key(for: Key.queueSongIDs))?
            .map(MusicItemID.init(rawValue:)) ?? []

        return PlaybackRestorationSnapshot(
            queueSongIDs: queueSongIDs,
            currentSongID: MusicItemID(rawValue: currentSongID),
            playbackTime: playbackTime
        )
    }

    func save(_ snapshot: PlaybackRestorationSnapshot) {
        defaults.set(
            snapshot.queueSongIDs.map(\.rawValue),
            forKey: key(for: Key.queueSongIDs)
        )
        defaults.set(snapshot.currentSongID.rawValue, forKey: key(for: Key.currentSongID))
        defaults.set(snapshot.playbackTime, forKey: key(for: Key.playbackTime))
    }

    func clear() {
        defaults.removeObject(forKey: key(for: Key.queueSongIDs))
        defaults.removeObject(forKey: key(for: Key.currentSongID))
        defaults.removeObject(forKey: key(for: Key.playbackTime))
    }

    private func key(for component: String) -> String {
        "\(keyPrefix).\(component)"
    }
}
