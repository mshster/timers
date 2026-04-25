// Timers/Models/LayoutMode.swift
enum LayoutMode: String, CaseIterable {
    case activeOnTop
    case activeInPlace

    var displayName: String {
        switch self {
        case .activeOnTop: return "Active timers on top"
        case .activeInPlace: return "Active timers in-place"
        }
    }
}
