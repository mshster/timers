import SwiftUI

struct SoundOption: Identifiable, Hashable {
    let id: String          // "" means use global default; "default" means UNNotificationSound.default
    let displayName: String
}

enum AvailableSounds {
    // Names map to <name>.caf in the iOS system audio library.
    // "default" is handled specially → UNNotificationSound.default.
    static let all: [SoundOption] = [
        SoundOption(id: "default", displayName: "Default"),
        SoundOption(id: "Apex",     displayName: "Apex"),
        SoundOption(id: "Bamboo",   displayName: "Bamboo"),
        SoundOption(id: "Chord",    displayName: "Chord"),
        SoundOption(id: "Circles",  displayName: "Circles"),
        SoundOption(id: "Complete", displayName: "Complete"),
        SoundOption(id: "Hello",    displayName: "Hello"),
        SoundOption(id: "Input",    displayName: "Input"),
        SoundOption(id: "Keys",     displayName: "Keys"),
        SoundOption(id: "Note",     displayName: "Note"),
        SoundOption(id: "Popcorn",  displayName: "Popcorn"),
        SoundOption(id: "Pulse",    displayName: "Pulse"),
        SoundOption(id: "Radar",    displayName: "Radar"),
        SoundOption(id: "Reflect",  displayName: "Reflect"),
        SoundOption(id: "Summit",   displayName: "Summit"),
        SoundOption(id: "Synth",    displayName: "Synth"),
        SoundOption(id: "Twinkle",  displayName: "Twinkle"),
        SoundOption(id: "Uplift",   displayName: "Uplift"),
        SoundOption(id: "Waves",    displayName: "Waves"),
    ]

    static let withInherit: [SoundOption] = [
        SoundOption(id: "", displayName: "Use default"),
    ] + all
}

struct SoundPickerView: View {
    @Binding var soundName: String
    var includeInheritOption: Bool = false

    private var options: [SoundOption] {
        includeInheritOption ? AvailableSounds.withInherit : AvailableSounds.all
    }

    var body: some View {
        Picker("Sound", selection: $soundName) {
            ForEach(options) { option in
                Text(option.displayName).tag(option.id)
            }
        }
    }
}
