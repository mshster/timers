// Timers/Models/TimerSection.swift
import Foundation

enum TimerRowItem {
    case profile(TimerProfile)
    case instance(TimerInstance)
}

struct TimerSection: Identifiable {
    let id: String
    let title: String?
    let rows: [TimerRowItem]
}
