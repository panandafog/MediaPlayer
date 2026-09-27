//
//  MacAccentTextField.swift
//  MediaPlayer
//

#if os(macOS)
import AppKit
import SwiftUI

struct MacAccentTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    let accentColor: Color?
    @Binding var isFocused: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: $isFocused, accentColor: accentColor)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = placeholder
        field.setAccessibilityLabel("Separator Characters")
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.text = $text
        context.coordinator.isFocused = $isFocused
        context.coordinator.accentColor = accentColor
        if field.stringValue != text {
            field.stringValue = text
        }
        MacTextInsertionPoint.update(in: field, accentColor: accentColor)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        var isFocused: Binding<Bool>
        var accentColor: Color?

        init(text: Binding<String>, isFocused: Binding<Bool>, accentColor: Color?) {
            self.text = text
            self.isFocused = isFocused
            self.accentColor = accentColor
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            isFocused.wrappedValue = true
            if let field = notification.object as? NSTextField {
                MacTextInsertionPoint.update(in: field, accentColor: accentColor)
            }
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else {
                return
            }
            text.wrappedValue = field.stringValue
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            isFocused.wrappedValue = false
        }
    }
}

enum MacTextInsertionPoint {
    static func update(in control: NSControl, accentColor: Color?) {
        guard let editor = control.currentEditor() as? NSTextView else {
            return
        }

        let color = accentColor.map { NSColor($0) } ?? .textColor
        guard editor.insertionPointColor != color else {
            return
        }
        editor.insertionPointColor = color
        editor.updateInsertionPointStateAndRestartTimer(true)
    }
}
#endif
