//
//  PlayerWindow.swift
//  MediaPlayer
//
//

#if os(macOS)
import AppKit
import MusicKit
import SwiftUI

struct PlayerWindow: View {
    static let id = "player-window"
    static let minimumSize = CGSize(width: 180, height: 100)
    static let idealSize = CGSize(width: 380, height: 560)

    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme

    @ObservedObject var player: MusicPlayerViewModel
    @ObservedObject var library: MusicLibraryViewModel
    @ObservedObject var mainWindowNavigation: MainWindowNavigation
    @AppStorage(PlayerSettingsKey.usesLiquidGlassInPlayerWindow)
    private var usesLiquidGlassInPlayerWindow = true
    @State private var isFullScreen = false
    @State private var usesCompactChrome = false

    var body: some View {
        NowPlayingView(
            player: player,
            onOpenArtist: openArtist,
            onOpenAlbum: openAlbum
        )
        .environment(
            \.colorScheme,
            player.currentSong?.artwork == nil ? colorScheme : .dark
        )
        .containerBackground(for: .window) {
            if let artwork = player.currentSong?.artwork {
                PlayerArtworkBackground(artwork: artwork)
            } else if isFullScreen || !usesLiquidGlassInPlayerWindow {
                Color(nsColor: .windowBackgroundColor)
            } else {
                PlayerWindowGlassBackground()
            }
        }
        .background(
            PlayerWindowConfigurator(
                isFullScreen: $isFullScreen,
                usesCompactChrome: $usesCompactChrome
            )
        )
        .task {
            await library.loadIfAuthorized()
        }
        .frame(
            minWidth: Self.minimumSize.width,
            idealWidth: Self.idealSize.width,
            minHeight: Self.minimumSize.height,
            idealHeight: Self.idealSize.height
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
    @Binding var isFullScreen: Bool
    @Binding var usesCompactChrome: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(
            isFullScreen: $isFullScreen,
            usesCompactChrome: $usesCompactChrome
        )
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.update(
            isFullScreen: $isFullScreen,
            usesCompactChrome: $usesCompactChrome
        )
        context.coordinator.attach(to: nsView)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    @MainActor
    final class Coordinator: NSObject {
        private var isFullScreen: Binding<Bool>
        private var usesCompactChrome: Binding<Bool>
        private weak var window: NSWindow?
        private var observers: [NSObjectProtocol] = []
        private let delegateProxy = PlayerWindowDelegateProxy()

        init(isFullScreen: Binding<Bool>, usesCompactChrome: Binding<Bool>) {
            self.isFullScreen = isFullScreen
            self.usesCompactChrome = usesCompactChrome
        }

        func update(
            isFullScreen: Binding<Bool>,
            usesCompactChrome: Binding<Bool>
        ) {
            self.isFullScreen = isFullScreen
            self.usesCompactChrome = usesCompactChrome
        }

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

            window?.standardWindowButton(.miniaturizeButton)?.isHidden = false
            window?.standardWindowButton(.zoomButton)?.isHidden = false

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
            isFullScreen.wrappedValue = window.styleMask.contains(.fullScreen)

            let names: [Notification.Name] = [
                NSWindow.didBecomeKeyNotification,
                NSWindow.didResizeNotification,
                NSWindow.didUpdateNotification,
                NSWindow.willEnterFullScreenNotification,
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
                        if name == NSWindow.willEnterFullScreenNotification
                            || name == NSWindow.didEnterFullScreenNotification {
                            self.isFullScreen.wrappedValue = true
                        } else if name == NSWindow.didExitFullScreenNotification {
                            self.isFullScreen.wrappedValue = false
                        }

                        self.configure(window)
                    }
                }
            }
        }

        private func configure(_ window: NSWindow) {
            let shouldUseCompactChrome = !isFullScreen.wrappedValue
                && PlayerWindowChromeLayout.usesCompactChrome(for: window.frame.size)
            if usesCompactChrome.wrappedValue != shouldUseCompactChrome {
                usesCompactChrome.wrappedValue = shouldUseCompactChrome
            }

            var collectionBehavior = window.collectionBehavior
            collectionBehavior.insert(.fullScreenPrimary)
            collectionBehavior.remove(.fullScreenAuxiliary)
            collectionBehavior.remove(.fullScreenNone)
            window.collectionBehavior = collectionBehavior

            if window.delegate !== delegateProxy {
                delegateProxy.originalDelegate = window.delegate
                window.delegate = delegateProxy
            }

            window.standardWindowButton(.miniaturizeButton)?.isHidden = shouldUseCompactChrome

            if let fullScreenButton = window.standardWindowButton(.zoomButton) {
                fullScreenButton.isHidden = shouldUseCompactChrome
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

enum PlayerWindowChromeLayout {
    static func usesCompactChrome(for windowSize: CGSize) -> Bool {
        // Window size stays stable when the toolbar item disappears.
        windowSize.height < 230
            || (windowSize.width < 300 && windowSize.height < 360)
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
