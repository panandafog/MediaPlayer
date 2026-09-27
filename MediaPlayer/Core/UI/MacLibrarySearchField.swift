//
//  MacLibrarySearchField.swift
//  MediaPlayer
//

#if os(macOS)
import AppKit
import SwiftUI

struct MacLibrarySearchField: NSViewRepresentable {
    @EnvironmentObject private var artworkAccentTheme: ArtworkAccentTheme
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, accentColor: artworkAccentTheme.color)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField()
        searchField.placeholderString = "Search library"
        searchField.setAccessibilityLabel("Search music library")
        searchField.sendsSearchStringImmediately = true
        searchField.delegate = context.coordinator
        return searchField
    }

    func updateNSView(_ searchField: NSSearchField, context: Context) {
        context.coordinator.text = $text
        context.coordinator.accentColor = artworkAccentTheme.color
        if searchField.stringValue != text {
            searchField.stringValue = text
        }
        MacTextInsertionPoint.update(in: searchField, accentColor: artworkAccentTheme.color)
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var text: Binding<String>
        var accentColor: Color?

        init(text: Binding<String>, accentColor: Color?) {
            self.text = text
            self.accentColor = accentColor
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            guard let searchField = notification.object as? NSSearchField else {
                return
            }
            MacTextInsertionPoint.update(in: searchField, accentColor: accentColor)
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let searchField = notification.object as? NSSearchField else { return }
            text.wrappedValue = searchField.stringValue
        }
    }
}
#endif
