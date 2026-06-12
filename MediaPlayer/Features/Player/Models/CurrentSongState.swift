//
//  CurrentSongState.swift
//  MediaPlayer
//
//  Created by Codex on 31.05.2026.
//

import Combine
import MusicKit

@MainActor
final class CurrentSongState: ObservableObject {
    @Published private(set) var songID: MusicItemID?

    func update(to songID: MusicItemID?) {
        guard self.songID != songID else {
            return
        }

        self.songID = songID
    }
}
