// Timers/Models/TimerProfile.swift
import Foundation
import SwiftData

@Model
final class TimerProfile {
    var id: UUID
    var name: String
    var duration: TimeInterval
    var group: String?
    var soundName: String?
    var sortOrder: Int

    init(name: String, duration: TimeInterval, group: String? = nil,
         soundName: String? = nil, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.duration = duration
        self.group = group
        self.soundName = soundName
        self.sortOrder = sortOrder
    }
}
