// Timers/Models/TimerInstance.swift
import Foundation
import ActivityKit

enum InstanceState: Codable, Equatable {
    case running
    case finished
}

struct TimerInstance: Identifiable {
    let id: UUID
    let profileId: UUID?
    let displayName: String
    let groupName: String?
    let duration: TimeInterval
    let startTime: Date
    let soundName: String
    var state: InstanceState
    var activity: Activity<TimerAttributes>?

    init(id: UUID, profileId: UUID?, displayName: String, groupName: String? = nil,
         duration: TimeInterval, startTime: Date, soundName: String,
         state: InstanceState, activity: Activity<TimerAttributes>? = nil) {
        self.id = id
        self.profileId = profileId
        self.displayName = displayName
        self.groupName = groupName
        self.duration = duration
        self.startTime = startTime
        self.soundName = soundName
        self.state = state
        self.activity = activity
    }

    var isFinished: Bool { state == .finished }

    var remainingSeconds: TimeInterval {
        max(0, duration - Date().timeIntervalSince(startTime))
    }
}
