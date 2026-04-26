import SwiftUI
import AudioToolbox

struct SoundOption: Identifiable, Hashable {
    let id: String          // "" means inherit global default; "default" means UNNotificationSound.default
    let displayName: String
}

enum AvailableSounds {
    // Discovered once at first access from the iOS system audio directory.
    // Only capitalized names are included — this excludes UI feedback sounds
    // (lock.caf, keyboard_press_key.caf, etc.) while keeping alert tones.
    // Falls back to just [Default] if the directory isn't readable.
    static let all: [SoundOption] = {
        var options = [SoundOption(id: "default", displayName: "Default")]
        let dir = "/System/Library/Audio/UISounds"
        if let files = try? FileManager.default.contentsOfDirectory(atPath: dir) {
            let names = files
                .filter { $0.hasSuffix(".caf") && $0.first?.isUppercase == true }
                .map { String($0.dropLast(4)) }
                .sorted()
            options += names.map { SoundOption(id: $0, displayName: $0) }
        }
        return options
    }()

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
        .onChange(of: soundName) { _, newValue in
            previewSound(newValue)
        }
    }

    private func previewSound(_ soundId: String) {
        switch soundId {
        case "":
            return
        case "default":
            // kSystemSoundID_UserPreferredAlert plays whatever alert sound
            // the user has selected in Settings > Sounds & Haptics.
            AudioServicesPlaySystemSound(SystemSoundID(0x1000)) // kSystemSoundID_UserPreferredAlert
        default:
            let url = URL(fileURLWithPath: "/System/Library/Audio/UISounds/\(soundId).caf")
            var sid: SystemSoundID = 0
            guard AudioServicesCreateSystemSoundID(url as CFURL, &sid) == kAudioServicesNoError else { return }
            AudioServicesPlayAlertSoundWithCompletion(sid) {
                AudioServicesDisposeSystemSoundID(sid)
            }
        }
    }
}
