//
//  PlayerSettingsView.swift
//  MediaPlayer
//

import SwiftUI

struct PlayerSettingsView: View {
#if os(iOS)
    @Environment(\.dismiss) private var dismiss
    @AppStorage(PlayerSettingsKey.searchBarPosition) private var searchBarPosition =
        SearchBarPosition.top.rawValue
#endif

    var body: some View {
#if os(iOS)
        NavigationStack {
            settingsForm
                .navigationTitle("Settings")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
#else
        settingsForm
            .padding(20)
            .frame(width: 540, height: 600)
#endif
    }

    private var settingsForm: some View {
        Form {
#if os(iOS)
            Section("Library") {
                Picker("Search Position", selection: $searchBarPosition) {
                    ForEach(SearchBarPosition.allCases) { position in
                        Text(position.title)
                            .tag(position.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }
#endif

            Section("Equalizer") {
                EqualizerSettingsView()
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    PlayerSettingsView()
}
