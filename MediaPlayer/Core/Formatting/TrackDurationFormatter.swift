//
//  TrackDurationFormatter.swift
//  MediaPlayer
//
//  Created by Codex on 31.05.2026.
//

import Foundation

enum TrackDurationFormatter {
    static func string(from duration: TimeInterval?) -> String {
        guard let duration, duration.isFinite, duration >= 0 else {
            return "--:--"
        }

        let totalSeconds = Int(duration.rounded(.down))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}
