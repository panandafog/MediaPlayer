//
//  PlayerWindow.swift
//  MediaPlayer
//
//  Created by Codex on 31.05.2026.
//

#if os(macOS)
import AppKit
import MusicKit
import SwiftUI

struct PlayerWindow: View {
    static let id = "player-window"

    @Environment(\.openWindow) private var openWindow

    @ObservedObject var player: MusicPlayerViewModel
    @ObservedObject var library: MusicLibraryViewModel
    @ObservedObject var mainWindowNavigation: MainWindowNavigation

    var body: some View {
        NavigationStack {
            NowPlayingView(
                player: player,
                onOpenArtist: openArtist,
                onOpenAlbum: openAlbum
            )
        }
        .containerBackground(for: .window) {
            PlayerWindowGlassBackground()
        }
        .background(PlayerWindowConfigurator())
        .task {
            await library.loadIfAuthorized()
        }
        .frame(
            minWidth: 180,
            idealWidth: 380,
            minHeight: 100,
            idealHeight: 560
        )
    }

    private func openArtist(for song: Song) {
        guard let artist = library.artist(containing: song) else {
            return
        }

        open(.artist(artist.id))
    }

    private func openAlbum(for song: Song) {
        guard let album = library.album(containing: song) else {
            return
        }

        open(.album(album.id))
    }

    private func open(_ destination: LibraryNavigationDestination) {
        mainWindowNavigation.open(destination)
        openWindow(id: MainWindowNavigation.windowID)
    }
}

private struct PlayerWindowGlassBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSGlassEffectView {
        let glassView = NSGlassEffectView()
        glassView.style = .regular
        glassView.cornerRadius = 0
        return glassView
    }

    func updateNSView(_ nsView: NSGlassEffectView, context: Context) {}
}

private struct PlayerWindowConfigurator: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.attach(to: nsView)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    @MainActor
    final class Coordinator: NSObject {
        private weak var window: NSWindow?
        private var observers: [NSObjectProtocol] = []
        private let delegateProxy = PlayerWindowDelegateProxy()

        func attach(to view: NSView) {
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self, let window = view?.window else {
                    return
                }

                if self.window !== window {
                    self.observe(window)
                }

                self.configure(window)
            }
        }

        func detach() {
            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()

            if window?.delegate === delegateProxy {
                window?.delegate = delegateProxy.originalDelegate
            }

            delegateProxy.originalDelegate = nil
            window = nil
        }

        @objc
        private func toggleFullScreen(_ sender: Any?) {
            window?.toggleFullScreen(sender)
        }

        private func observe(_ window: NSWindow) {
            detach()
            self.window = window

            let names: [Notification.Name] = [
                NSWindow.didBecomeKeyNotification,
                NSWindow.didUpdateNotification,
                NSWindow.didEnterFullScreenNotification,
                NSWindow.didExitFullScreenNotification
            ]

            observers = names.map { name in
                NotificationCenter.default.addObserver(
                    forName: name,
                    object: window,
                    queue: .main
                ) { [weak self, weak window] _ in
                    guard let self, let window else {
                        return
                    }

                    Task { @MainActor in
                        self.configure(window)
                    }
                }
            }
        }

        private func configure(_ window: NSWindow) {
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.titlebarSeparatorStyle = .none
            window.styleMask.insert(.fullSizeContentView)

            var collectionBehavior = window.collectionBehavior
            collectionBehavior.insert(.fullScreenPrimary)
            collectionBehavior.remove(.fullScreenAuxiliary)
            collectionBehavior.remove(.fullScreenNone)
            window.collectionBehavior = collectionBehavior

            if window.delegate !== delegateProxy {
                delegateProxy.originalDelegate = window.delegate
                window.delegate = delegateProxy
            }

            if let fullScreenButton = window.standardWindowButton(.zoomButton) {
                fullScreenButton.isEnabled = true
                fullScreenButton.target = self
                fullScreenButton.action = #selector(toggleFullScreen(_:))
                fullScreenButton.toolTip = window.styleMask.contains(.fullScreen)
                    ? "Exit Full Screen"
                    : "Enter Full Screen"
            }
        }
    }
}

@MainActor
private final class PlayerWindowDelegateProxy: NSObject, NSWindowDelegate {
    weak var originalDelegate: NSWindowDelegate?

    // SwiftUI may restore the zoom action after the title bar updates.
    func windowShouldZoom(_ window: NSWindow, toFrame newFrame: NSRect) -> Bool {
        DispatchQueue.main.async { [weak window] in
            window?.toggleFullScreen(nil)
        }

        return false
    }

    override func responds(to selector: Selector!) -> Bool {
        super.responds(to: selector) || originalDelegate?.responds(to: selector) == true
    }

    override func forwardingTarget(for selector: Selector!) -> Any? {
        if originalDelegate?.responds(to: selector) == true {
            return originalDelegate
        }

        return super.forwardingTarget(for: selector)
    }
}
#endif
