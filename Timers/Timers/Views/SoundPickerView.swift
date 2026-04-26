import SwiftUI
import AudioToolbox

struct SoundOption: Identifiable, Hashable {
    // "" → inherit global default
    // "default" → UNNotificationSound.default
    // anything else → filename with extension (e.g. "sms_alert_bamboo.caf")
    let id: String
    let displayName: String
}

enum AvailableSounds {
    private static let searchDirs = [
        "/System/Library/Audio/UISounds",
        "/System/Library/Audio/UISounds/Modern",
        "/System/Library/Audio/UISounds/New",
    ]
    private static let audioExtensions: Set<String> = ["caf", "m4r"]
    private static let stripPrefixes = ["sms_alert_", "calendar_alert_", "alarm_"]
    private static let stripSuffixes = ["-EncoreInfinitum"]

    // Discovered once at first access. Searches known system audio directories,
    // strips housekeeping prefixes/suffixes, deduplicates by display name.
    static let all: [SoundOption] = {
        var seen = Set<String>()
        var options = [SoundOption(id: "default", displayName: "Default")]
        seen.insert("default")

        var discovered: [(displayName: String, filename: String)] = []

        for dir in searchDirs {
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir) else { continue }
            for file in files {
                let ext = (file as NSString).pathExtension
                guard audioExtensions.contains(ext) else { continue }

                var name = (file as NSString).deletingPathExtension
                for suffix in stripSuffixes where name.hasSuffix(suffix) {
                    name = String(name.dropLast(suffix.count))
                }
                for prefix in stripPrefixes where name.hasPrefix(prefix) {
                    name = String(name.dropFirst(prefix.count))
                    break
                }
                name = name.prefix(1).uppercased() + name.dropFirst()

                guard !name.isEmpty, !seen.contains(name.lowercased()) else { continue }
                seen.insert(name.lowercased())
                discovered.append((displayName: name, filename: file))
            }
        }

        discovered.sort { $0.displayName < $1.displayName }
        options += discovered.map { SoundOption(id: $0.filename, displayName: $0.displayName) }
        return options
    }()

    static let withInherit: [SoundOption] = [
        SoundOption(id: "", displayName: "Use default"),
    ] + all

    static func filePath(for soundId: String) -> String? {
        for dir in searchDirs {
            let path = "\(dir)/\(soundId)"
            if FileManager.default.fileExists(atPath: path) { return path }
        }
        return nil
    }
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
            // kSystemSoundID_UserPreferredAlert — whatever the user set in Settings
            AudioServicesPlaySystemSound(SystemSoundID(0x1000))
        default:
            guard let path = AvailableSounds.filePath(for: soundId) else { return }
            var sid: SystemSoundID = 0
            let url = URL(fileURLWithPath: path)
            guard AudioServicesCreateSystemSoundID(url as CFURL, &sid) == kAudioServicesNoError else { return }
            AudioServicesPlayAlertSoundWithCompletion(sid) {
                AudioServicesDisposeSystemSoundID(sid)
            }
        }
    }
}
