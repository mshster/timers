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
                    HStack {
                        Spacer(minLength: 0)
                        CountdownLabel(context: context)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    timerProgress(context: context)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(.green)
                    .font(.caption2)
            } compactTrailing: {
                Text(context.state.endDate, style: .timer)
                    .monospacedDigit()
                    .font(.caption2)
                    .frame(minWidth: 28, maxWidth: 44)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(.green)
                    .font(.caption2)
            }
        }
    }

    @ViewBuilder
    private func timerProgress(context: ActivityViewContext<TimerAttributes>) -> some View {
        if context.state.isFinished {
            ProgressView(value: 1.0, total: 1.0)
                .tint(.green)
        } else {
            let startDate = context.state.endDate.addingTimeInterval(-context.attributes.totalDuration)
            ProgressView(timerInterval: startDate...context.state.endDate, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(.green)
        }
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
                .font(.caption.bold())
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<TimerAttributes>

    private var displayName: String {
        if let group = context.attributes.groupName {
            return "\(group) : \(context.attributes.profileName)"
        }
        return context.attributes.profileName
    }

    var body: some View {
        HStack {
            Label(displayName, systemImage: "timer")
                .font(.headline)
                .lineLimit(1)
            Spacer()
            if context.state.isFinished {
                Text("Done")
                    .foregroundStyle(.green)
                    .font(.headline.bold())
            } else {
                Text(context.state.endDate, style: .timer)
                    .font(.headline.bold())
                    .monospacedDigit()
                    .fixedSize()
            }
        }
        .padding()
    }
}
