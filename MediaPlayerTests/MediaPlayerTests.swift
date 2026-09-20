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

    @Test func mapsListeningModesToNativeRepeatMode() {
        #expect(PlaybackMode.normal.nativeRepeatMode == .none)
        #expect(PlaybackMode.shuffle.nativeRepeatMode == .none)
        #expect(PlaybackMode.repeatQueue.nativeRepeatMode == .all)
        #expect(PlaybackMode.repeatOne.nativeRepeatMode == .one)
    }

    @Test func shufflesActualPlaybackQueueStartingWithCurrentItem() {
        let items = Array(0..<5)
        let shuffledItems = PlaybackQueueOrder.shuffledItems(
            from: items,
            startingAt: 2,
            shuffle: { _ in }
        )

        #expect(shuffledItems == [0, 1, 2, 4, 3])
        #expect(Set(shuffledItems) == Set(items))
    }

    @Test func persistsPlayerSettingsAcrossLaunches() throws {
        let suiteName = "MediaPlayerTests.\(UUID().uuidString)"
        let firstLaunchDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            firstLaunchDefaults.removePersistentDomain(forName: suiteName)
        }

        firstLaunchDefaults.set(
            false,
            forKey: PlayerSettingsKey.usesLiquidGlassInPlayerWindow
        )
        firstLaunchDefaults.set("bottom", forKey: PlayerSettingsKey.searchBarPosition)
        firstLaunchDefaults.set(
            true,
            forKey: PlayerSettingsKey.usesSmartArtistGrouping
        )
        firstLaunchDefaults.set(
            "|+",
            forKey: PlayerSettingsKey.smartArtistSeparatorCharacters
        )

        let nextLaunchDefaults = try #require(UserDefaults(suiteName: suiteName))

        #expect(
            nextLaunchDefaults.bool(
                forKey: PlayerSettingsKey.usesLiquidGlassInPlayerWindow
            ) == false
        )
        #expect(
            nextLaunchDefaults.string(forKey: PlayerSettingsKey.searchBarPosition)
                == "bottom"
        )
        #expect(
            nextLaunchDefaults.bool(forKey: PlayerSettingsKey.usesSmartArtistGrouping)
        )
        #expect(
            nextLaunchDefaults.string(
                forKey: PlayerSettingsKey.smartArtistSeparatorCharacters
            ) == "|+"
        )
    }

    @Test @MainActor func restoresLibraryBrowsingPreferences() throws {
        let suiteName = "MediaPlayerTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set(
            MusicLibrarySortOption.artist.rawValue,
            forKey: PlayerSettingsKey.librarySortOption
        )
        defaults.set(
            MusicLibrarySection.albums.rawValue,
            forKey: PlayerSettingsKey.librarySection
        )

        let restoredLibrary = MusicLibraryViewModel(defaults: defaults)

        #expect(restoredLibrary.sortOption == .artist)
        #expect(restoredLibrary.section == .albums)

        restoredLibrary.sortOption = .album
        restoredLibrary.section = .artists

        let nextLaunchLibrary = MusicLibraryViewModel(defaults: defaults)

        #expect(nextLaunchLibrary.sortOption == .album)
        #expect(nextLaunchLibrary.section == .artists)
    }

    @Test func separatesCombinedArtistNamesUsingUnambiguousDelimiters() {
        #expect(
            CombinedArtistNameParser.names(from: "Boris Brejcha; Ginger")
                == ["Boris Brejcha", "Ginger"]
        )
        #expect(
            CombinedArtistNameParser.names(from: "Artist feat. Guest")
                == ["Artist", "Guest"]
        )
        #expect(
            CombinedArtistNameParser.names(from: "Artist / Guest x Third")
                == ["Artist", "Guest", "Third"]
        )
        #expect(
            CombinedArtistNameParser.names(
                from: "Artist One,Artist Two & Artist Three/Artist Four"
            ) == ["Artist One", "Artist Two", "Artist Three", "Artist Four"]
        )
    }

    @Test func usesCustomArtistSeparatorCharactersLiterally() {
        #expect(
            CombinedArtistNameParser.names(
                from: "Artist One|Artist Two+Artist Three",
                separatorCharacters: "|+"
            ) == ["Artist One", "Artist Two", "Artist Three"]
        )
        #expect(
            CombinedArtistNameParser.names(
                from: "Artist.One*Artist Two",
                separatorCharacters: ".*"
            ) == ["Artist", "One", "Artist Two"]
        )
        #expect(
            CombinedArtistNameParser.names(
                from: "Artist One; Artist Two",
                separatorCharacters: "|"
            ) == ["Artist One; Artist Two"]
        )
    }

    @Test func normalizesCustomArtistSeparatorCharacters() {
        #expect(
            SmartArtistGroupingSettings.normalizedSeparatorCharacters(" , , & / ")
                == ",&/"
        )
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
