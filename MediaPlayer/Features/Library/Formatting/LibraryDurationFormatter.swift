//
//  LibraryDurationFormatter.swift
//  MediaPlayer
//

import Foundation

nonisolated enum LibraryDurationFormatter {
    static func string(from duration: TimeInterval) -> String {
        let totalMinutes = Int(duration / 60)
        guard totalMinutes >= 60 else {
            return totalMinutes == 0 ? "<1m" : "\(totalMinutes)m"
        }

        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
    }
}
