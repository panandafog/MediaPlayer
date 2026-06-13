//
//  PlaybackQueueOrder.swift
//  MediaPlayer
//

enum PlaybackQueueOrder {
    static func shuffledItems<Element: Equatable>(
        from items: [Element],
        startingAt index: Int,
        shuffle: (inout [Element]) -> Void = { $0.shuffle() }
    ) -> [Element] {
        guard items.indices.contains(index) else {
            return []
        }

        let playedAndCurrentItems = Array(items[...index])
        var futureItems = Array(items.dropFirst(index + 1))
        let originalFutureItems = futureItems
        shuffle(&futureItems)

        // Avoid presenting shuffle as a no-op when the random order happens to
        // match the original queue.
        if futureItems.count > 1, futureItems == originalFutureItems {
            futureItems.append(futureItems.removeFirst())
        }

        return playedAndCurrentItems + futureItems
    }
}
