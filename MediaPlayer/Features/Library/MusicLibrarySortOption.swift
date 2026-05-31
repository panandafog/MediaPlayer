//
//  MusicLibrarySortOption.swift
//  MediaPlayer
//
//  Created by Codex on 31.05.2026.
//

import Foundation
import MusicKit

enum MusicLibrarySortOption: String, CaseIterable, Identifiable {
    case title
    case album
    case artist

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .title:
            "Track Title"
        case .album:
            "Album"
        case .artist:
            "Artist"
        }
    }

    func areInIncreasingOrder(_ lhs: Song, _ rhs: Song) -> Bool {
        switch self {
        case .title:
            compare(
                lhs.title,
                lhs.artistName,
                lhs.albumTitle,
                to: rhs.title,
                rhs.artistName,
                rhs.albumTitle
            )
        case .album:
            compare(
                lhs.albumTitle,
                lhs.artistName,
                lhs.title,
                to: rhs.albumTitle,
                rhs.artistName,
                rhs.title
            )
        case .artist:
            compare(
                lhs.artistName,
                lhs.albumTitle,
                lhs.title,
                to: rhs.artistName,
                rhs.albumTitle,
                rhs.title
            )
        }
    }

    private func compare(
        _ lhsPrimary: String?,
        _ lhsSecondary: String?,
        _ lhsTertiary: String?,
        to rhsPrimary: String?,
        _ rhsSecondary: String?,
        _ rhsTertiary: String?
    ) -> Bool {
        let lhs = [lhsPrimary, lhsSecondary, lhsTertiary]
        let rhs = [rhsPrimary, rhsSecondary, rhsTertiary]

        for (lhsValue, rhsValue) in zip(lhs, rhs) {
            let result = (lhsValue ?? "").localizedStandardCompare(rhsValue ?? "")
            guard result != .orderedSame else {
                continue
            }

            return result == .orderedAscending
        }

        return false
    }
}
