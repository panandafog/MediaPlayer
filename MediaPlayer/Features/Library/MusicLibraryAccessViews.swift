//
//  MusicLibraryAccessViews.swift
//  MediaPlayer
//
//  Created by Codex on 31.05.2026.
//

import SwiftUI

struct PermissionView: View {
    let onRequestAccess: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Open Your Music Library", systemImage: "music.note.house")
        } description: {
            Text("The player needs access to your Music library to show and play your tracks.")
        } actions: {
            Button("Allow Access", action: onRequestAccess)
                .buttonStyle(.borderedProminent)
        }
    }
}

struct AccessUnavailableView: View {
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "exclamationmark.lock")
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}
