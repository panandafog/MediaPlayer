//
//  MusicLibrarySectionPicker.swift
//  MediaPlayer
//
//  Created by Codex on 31.05.2026.
//

import SwiftUI

struct MusicLibrarySectionPicker: View {
    @Binding var selection: MusicLibrarySection

    var body: some View {
        Picker("Library Section", selection: $selection) {
            ForEach(MusicLibrarySection.allCases) { section in
                Text(section.title)
                    .tag(section)
            }
        }
        .pickerStyle(.segmented)
        .padding()
    }
}
