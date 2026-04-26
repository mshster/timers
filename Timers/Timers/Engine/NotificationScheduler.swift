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
        // soundName is either "default", a bare legacy name ("Radar"), or
        // a filename-with-extension discovered at runtime ("sms_alert_bamboo.caf").
        let soundFilename = soundName.contains(".") ? soundName : soundName + ".caf"
        content.sound = soundName == "default"
            ? .default
            : UNNotificationSound(named: UNNotificationSoundName(rawValue: soundFilename))
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
}
