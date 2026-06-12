//
//  MainWindowNavigation.swift
//  MediaPlayer
//
//  Created by Codex on 13.06.2026.
//

#if os(macOS)
import Combine
import Foundation

@MainActor
final class MainWindowNavigation: ObservableObject {
    struct Request: Equatable {
        let id = UUID()
        let destination: LibraryNavigationDestination
    }

    static let windowID = "main-library"

    @Published private(set) var request: Request?

    func open(_ destination: LibraryNavigationDestination) {
        request = Request(destination: destination)
    }

    func consume(_ requestID: UUID) {
        guard request?.id == requestID else {
            return
        }

        request = nil
    }
}
#endif
