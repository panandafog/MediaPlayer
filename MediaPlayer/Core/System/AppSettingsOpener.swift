//
//  AppSettingsOpener.swift
//  MediaPlayer
//
//  Created by Codex on 31.05.2026.
//

import Foundation

#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

enum AppSettingsOpener {
    nonisolated static func open() {
        Task { @MainActor in
            openOnMainActor()
        }
    }

    private static func openOnMainActor() {
        #if os(macOS)
        NSWorkspace.shared.open(
            URL(fileURLWithPath: "/System/Applications/System Settings.app")
        )
        #elseif canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        UIApplication.shared.open(url)
        #endif
    }
}
