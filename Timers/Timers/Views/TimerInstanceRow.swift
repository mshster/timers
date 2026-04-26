// Timers/Views/TimerInstanceRow.swift
import SwiftUI

struct TimerInstanceRow: View {
    let instance: TimerInstance
    let onCancel: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(instance.displayName)
                    .font(.body)
                if instance.isFinished {
                    Text("Finished")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            Spacer()
            if instance.isFinished {
                Button("Dismiss", action: onDismiss)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
            } else {
                CountdownText(instance: instance)
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .listRowBackground(instance.isFinished ? Color.green.opacity(0.12) : nil)
    }
}

private struct CountdownText: View {
    let instance: TimerInstance

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            Text(formatRemaining(instance.remainingSeconds))
                .font(.body)
                .monospacedDigit()
        }
    }

    private func formatRemaining(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s)
                     : String(format: "%d:%02d", m, s)
    }
}
