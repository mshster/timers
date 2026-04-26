// Timers/Engine/NotificationScheduler.swift
import Foundation
import UserNotifications

protocol NotificationScheduler {
    func schedule(instanceId: UUID, displayName: String, soundName: String,
                  delay: TimeInterval) async throws
    func cancel(instanceId: UUID)
    func requestAuthorization() async throws -> Bool
}

final class LiveNotificationScheduler: NotificationScheduler {
    func schedule(instanceId: UUID, displayName: String, soundName: String,
                  delay: TimeInterval) async throws {
        let content = UNMutableNotificationContent()
        content.title = displayName
        content.body = "Timer finished"
        content.sound = resolvedSound(for: soundName)
        content.userInfo = ["instanceId": instanceId.uuidString]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(delay, 1), repeats: false)
        let request = UNNotificationRequest(identifier: instanceId.uuidString,
                                            content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(request)
    }

    func cancel(instanceId: UUID) {
        let id = instanceId.uuidString
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
    }

    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    // MARK: - Sound resolution

    private func resolvedSound(for soundName: String) -> UNNotificationSound {
        guard soundName != "default", !soundName.isEmpty else { return .default }
        // soundName is either a legacy bare name ("Radar") or a filename with
        // extension discovered at runtime ("sms_alert_bamboo.caf").
        let filename = soundName.contains(".") ? soundName : soundName + ".caf"
        // UNNotificationSound(named:) searches the app bundle and Library/Sounds.
        // Copy the file there on first use so iOS can find it.
        return copiedToLibrarySounds(filename)
            ? UNNotificationSound(named: UNNotificationSoundName(rawValue: filename))
            : .default
    }

    // Copies a system audio file into the app's Library/Sounds directory so
    // UNNotificationSound(named:) can locate it (documented search path).
    // Returns true if the file is ready in Library/Sounds.
    @discardableResult
    private func copiedToLibrarySounds(_ filename: String) -> Bool {
        let soundsDir = URL.libraryDirectory.appending(path: "Sounds", directoryHint: .isDirectory)
        let dest = soundsDir.appending(path: filename)
        if FileManager.default.fileExists(atPath: dest.path) { return true }

        let searchDirs = [
            "/System/Library/Audio/UISounds",
            "/System/Library/Audio/UISounds/Modern",
            "/System/Library/Audio/UISounds/New",
        ]
        for dir in searchDirs {
            let source = URL(fileURLWithPath: "\(dir)/\(filename)")
            guard FileManager.default.fileExists(atPath: source.path) else { continue }
            try? FileManager.default.createDirectory(at: soundsDir, withIntermediateDirectories: true)
            do {
                try FileManager.default.copyItem(at: source, to: dest)
                return true
            } catch {
                return false
            }
        }
        return false
    }
}
