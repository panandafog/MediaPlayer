//
//  PlaybackProgress.swift
//  MediaPlayer
//
//  Created by Codex on 31.05.2026.
//

import Foundation

enum PlaybackProgress {
    static func normalizedTime(_ time: TimeInterval, duration: TimeInterval?) -> TimeInterval {
        guard time.isFinite else {
            return 0
        }

        let nonnegativeTime = max(time, 0)
        guard let duration, duration.isFinite, duration > 0 else {
            return nonnegativeTime
        }

        return min(nonnegativeTime, duration)
    }
}
