// TimersWidgetExtension/TimersWidgetExtensionLiveActivity.swift
import ActivityKit
import WidgetKit
import SwiftUI

struct TimersLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerAttributes.self) { context in
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.profileName, systemImage: "timer")
                        .font(.caption)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CountdownLabel(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(
                        value: progressValue(context: context),
                        total: 1.0
                    )
                    .tint(.green)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(.green)
            } compactTrailing: {
                CountdownLabel(context: context)
            } minimal: {
                CountdownLabel(context: context)
            }
        }
    }

    private func progressValue(context: ActivityViewContext<TimerAttributes>) -> Double {
        guard !context.state.isFinished else { return 1.0 }
        let elapsed = context.state.endDate.timeIntervalSinceNow
        let remaining = max(0, elapsed)
        return 1.0 - (remaining / context.attributes.totalDuration)
    }
}

private struct CountdownLabel: View {
    let context: ActivityViewContext<TimerAttributes>

    var body: some View {
        if context.state.isFinished {
            Text("Done")
                .font(.caption.bold())
                .foregroundStyle(.green)
        } else {
            Text(context.state.endDate, style: .timer)
                .font(.system(.caption, design: .monospaced).bold())
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<TimerAttributes>

    var body: some View {
        HStack {
            Label(context.attributes.profileName, systemImage: "timer")
                .font(.headline)
            Spacer()
            if context.state.isFinished {
                Text("Done")
                    .foregroundStyle(.green)
                    .font(.headline.bold())
            } else {
                Text(context.state.endDate, style: .timer)
                    .font(.system(.headline, design: .monospaced).bold())
                    .monospacedDigit()
            }
        }
        .padding()
    }
}
