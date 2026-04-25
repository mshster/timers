// Timers/Models/TimerAttributes.swift
import ActivityKit
import Foundation

struct TimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var endDate: Date
        var isFinished: Bool
        var totalDuration: TimeInterval
    }

    let profileName: String
    let totalDuration: TimeInterval
}
