// Timers/Views/TimerProfileRow.swift
import SwiftUI

struct TimerProfileRow: View {
    let profile: TimerProfile
    let onStart: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onStart) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.body)
                    Text(formatDuration(profile.duration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "play.fill")
                    .foregroundStyle(.blue)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Edit", systemImage: "pencil", action: onEdit)
            Button("Duplicate", systemImage: "plus.square.on.square", action: onDuplicate)
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let total = Int(duration)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d hr %02d min", h, m) }
        if s > 0 { return String(format: "%d min %02d sec", m, s) }
        return String(format: "%d min", m)
    }
}
