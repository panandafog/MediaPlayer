//
//  PlaybackTimeState.swift
//  MediaPlayer
//
//

import Combine
import Foundation

@MainActor
final class PlaybackTimeState: ObservableObject {
    @Published private(set) var value: TimeInterval = 0

    func update(to value: TimeInterval) {
        guard self.value != value else {
            return
        }

        self.value = value
    }
}
