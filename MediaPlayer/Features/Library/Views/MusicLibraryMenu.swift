//
//  MusicLibraryMenu.swift
//  MediaPlayer
//
//  Created by Codex on 01.06.2026.
//

import SwiftUI

struct MusicLibraryMenu: View {
    @Binding var section: MusicLibrarySection
    @Binding var sortOption: MusicLibrarySortOption
    let isRefreshing: Bool
    let onRefresh: () -> Void

    var body: some View {
        Menu {
            Section("Browse") {
                Picker("Browse Library", selection: $section) {
                    ForEach(MusicLibrarySection.allCases) { section in
                        Label(section.title, systemImage: section.systemImage)
                            .tag(section)
                    }
                }
            }

            if section == .songs {
                Section("Sort Songs") {
                    Picker("Sort Songs", selection: $sortOption) {
                        ForEach(MusicLibrarySortOption.allCases) { option in
                            Text(option.title)
                                .tag(option)
                        }
                    }
                }
            }

            Divider()

            Button(action: onRefresh) {
                Label(
                    isRefreshing ? "Refreshing Library..." : "Refresh Library",
                    systemImage: "arrow.clockwise"
                )
            }
            .disabled(isRefreshing)
        } label: {
            Label(section.title, systemImage: section.systemImage)
        }
        .accessibilityLabel("Library Options")
    }
}
