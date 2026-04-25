import SwiftUI

struct SoundOption: Identifiable, Hashable {
    let id: String          // "" means use global default; "default" means UNNotificationSound.default
    let displayName: String
}

enum AvailableSounds {
    static let all: [SoundOption] = [
        SoundOption(id: "default", displayName: "Default"),
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
