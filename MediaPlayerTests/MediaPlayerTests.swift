//
//  MediaPlayerTests.swift
//  MediaPlayerTests
//
//  Created by Andrey Pantyuhin on 31.05.2026.
//

import Foundation
import MusicKit
import Testing
@testable import PlayerApp

struct MediaPlayerTests {

    @Test func formatsTrackDuration() {
        #expect(TrackDurationFormatter.string(from: 0) == "0:00")
        #expect(TrackDurationFormatter.string(from: 65.9) == "1:05")
        #expect(TrackDurationFormatter.string(from: nil) == "--:--")
    }

    @Test func normalizesPlaybackProgress() {
        #expect(PlaybackProgress.normalizedTime(-1, duration: 120) == 0)
        #expect(PlaybackProgress.normalizedTime(30, duration: 120) == 30)
        #expect(PlaybackProgress.normalizedTime(150, duration: 120) == 120)
        #expect(PlaybackProgress.normalizedTime(.infinity, duration: 120) == 0)
    }

    @Test func limitsPlaybackQueueAroundSelectedItem() {
        let items = Array(0..<1_000)
        let window = PlaybackQueueWindow.items(from: items, startingAt: 500)

        #expect(window.first == 490)
        #expect(window.last == 550)
        #expect(window.count == 61)
    }

    @Test func limitsPlaybackQueueAtCollectionEdges() {
        let items = Array(0..<1_000)

        #expect(PlaybackQueueWindow.items(from: items, startingAt: 10).first == 0)
        #expect(PlaybackQueueWindow.items(from: items, startingAt: 10).last == 60)
        #expect(PlaybackQueueWindow.items(from: items, startingAt: 999).first == 989)
        #expect(PlaybackQueueWindow.items(from: items, startingAt: 999).last == 999)
    }

    @Test func returnsItemsAfterCurrentQueueEntry() {
        let items = Array(0..<5)

        #expect(PlaybackQueueWindow.itemsAfterCurrent(in: items, currentIndex: 1) == [2, 3, 4])
        #expect(PlaybackQueueWindow.itemsAfterCurrent(in: items, currentIndex: 4).isEmpty)
        #expect(PlaybackQueueWindow.itemsAfterCurrent(in: items, currentIndex: nil).isEmpty)
    }

    @Test func definesSixEqualizerBandsWithUniqueStorageKeys() {
        let bands = EqualizerBand.allCases

        #expect(bands.map(\.title) == ["60 Hz", "150 Hz", "400 Hz", "1 kHz", "2.4 kHz", "15 kHz"])
        #expect(Set(bands.map(\.defaultsKey)).count == bands.count)
    }

    @Test @MainActor func storesPlaybackRestorationSnapshot() throws {
        let suiteName = "MediaPlayerTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = PlaybackRestorationStore(defaults: defaults)
        let snapshot = PlaybackRestorationSnapshot(
            queueSongIDs: ["first", "second"],
            currentSongID: "second",
            playbackTime: 42.5
        )

        store.save(snapshot)

        #expect(store.load() == snapshot)
    }

}
