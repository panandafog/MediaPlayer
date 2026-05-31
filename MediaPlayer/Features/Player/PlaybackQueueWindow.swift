//
//  PlaybackQueueWindow.swift
//  MediaPlayer
//
//  Created by Codex on 31.05.2026.
//

enum PlaybackQueueWindow {
    static let precedingItemLimit = 50
    static let followingItemLimit = 200

    static func items<Element>(
        from items: [Element],
        startingAt index: Int
    ) -> [Element] {
        guard items.indices.contains(index) else {
            return []
        }

        let lowerBound = max(items.startIndex, index - precedingItemLimit)
        let upperBound = min(items.endIndex, index + followingItemLimit + 1)

        return Array(items[lowerBound..<upperBound])
    }
}
