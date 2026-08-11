//
//  ArtistLibraryMenu.swift
//  MediaPlayer
//
//

import SwiftUI

struct ArtistLibraryMenu: View {
    @Binding var selection: ArtistLibrarySection

    var body: some View {
        Menu {
            Picker("Browse Artist", selection: $selection) {
                ForEach(ArtistLibrarySection.allCases) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                }
            }
        } label: {
            Label(selection.title, systemImage: selection.systemImage)
        }
        .accessibilityLabel("Artist Options")
    }
}
