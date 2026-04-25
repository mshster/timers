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
    let duration: TimeInterval
    let startTime: Date
    let soundName: String
    var state: InstanceState
    var activity: Activity<TimerAttributes>?

    var isFinished: Bool { state == .finished }

    var remainingSeconds: TimeInterval {
        max(0, duration - Date().timeIntervalSince(startTime))
    }
}
