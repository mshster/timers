// Timers/Views/AdHocSheet.swift
import SwiftUI

struct AdHocSheet: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    @AppStorage("defaultSoundName") private var defaultSoundName: String = "default"

    @State private var duration: TimeInterval = 60
    @State private var soundName: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CountdownPickerView(duration: $duration)
                        .frame(height: 180)
                }
                Section("Sound") {
                    SoundPickerView(soundName: $soundName)
                }
            }
            .navigationTitle("Quick Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        engine.startAdHoc(duration: duration, soundName: soundName)
                        dismiss()
                    }
                    .disabled(duration <= 0)
                }
            }
            .onAppear { soundName = defaultSoundName }
        }
    }
}
