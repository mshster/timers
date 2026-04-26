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
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
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
}

// Expanded DI: .bottom region spans the full DI width, giving HStack a
// real container so Spacer works and the countdown sits at the right edge.
private struct ExpandedBottomView: View {
    let context: ActivityViewContext<TimerAttributes>

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Label(context.attributes.profileName, systemImage: "timer")
                    .font(.caption)
                    .lineLimit(1)
                Spacer(minLength: 8)
                CountdownLabel(context: context)
                    .frame(minWidth: 36, maxWidth: 66, alignment: .trailing)
            }
            timerProgress(context: context)
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func timerProgress(context: ActivityViewContext<TimerAttributes>) -> some View {
        if context.state.isFinished {
            ProgressView(value: 1.0, total: 1.0)
                .tint(.green)
        } else {
            let start = context.state.endDate.addingTimeInterval(-context.attributes.totalDuration)
            ProgressView(timerInterval: start...context.state.endDate, countsDown: false) {
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

// Lock screen: timer text gets a bounded frame so it cannot inflate and
// steal width from the label. Text is right-aligned within that frame.
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
            Spacer(minLength: 8)
            if context.state.isFinished {
                Text("Done")
                    .foregroundStyle(.green)
                    .font(.headline.bold())
            } else {
                Text(context.state.endDate, style: .timer)
                    .font(.headline.bold())
                    .monospacedDigit()
                    .frame(minWidth: 60, maxWidth: 90, alignment: .trailing)
            }
        }
        .padding()
    }
}
