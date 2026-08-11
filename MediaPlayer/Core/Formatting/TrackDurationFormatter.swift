//
//  TrackDurationFormatter.swift
//  MediaPlayer
//
//

import Foundation

enum TrackDurationFormatter {
    private static let secondsPerMinute = 60

    static func string(from duration: TimeInterval?) -> String {
        guard let duration, duration.isFinite, duration >= 0 else {
            return "--:--"
        }

        let totalSeconds = Int(duration.rounded(.down))
        let minutes = totalSeconds / secondsPerMinute
        let seconds = totalSeconds % secondsPerMinute
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}
