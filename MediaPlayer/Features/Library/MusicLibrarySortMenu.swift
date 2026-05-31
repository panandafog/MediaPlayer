//
//  MusicLibrarySortMenu.swift
//  MediaPlayer
//
//  Created by Codex on 31.05.2026.
//

import SwiftUI

struct MusicLibrarySortMenu: View {
    @Binding var selection: MusicLibrarySortOption

    var body: some View {
        Menu {
            Picker("Sort Library", selection: $selection) {
                ForEach(MusicLibrarySortOption.allCases) { option in
                    Text(option.title)
                        .tag(option)
                }
            }
        } label: {
            Label("Sort Library", systemImage: "arrow.up.arrow.down")
        }
    }
}
