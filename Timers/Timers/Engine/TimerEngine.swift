// Timers/Engine/TimerEngine.swift
import Foundation
import Observation
import UserNotifications
import ActivityKit
import Combine

@Observable
@MainActor
final class TimerEngine: NSObject {
    private(set) var instances: [TimerInstance] = []

    private let scheduler: NotificationScheduler
    private let clock: () -> Date
    private var tickCancellable: AnyCancellable?

    init(scheduler: NotificationScheduler = LiveNotificationScheduler(),
         clock: @escaping () -> Date = { Date() }) {
        self.scheduler = scheduler
        self.clock = clock
        super.init()
        UNUserNotificationCenter.current().delegate = self
        startTick()
    }

    // MARK: - Public API

    func start(profile: TimerProfile) {
        let sound = profile.soundName ?? defaultSoundName
        let instance = TimerInstance(
            id: UUID(), profileId: profile.id, displayName: profile.name,
            groupName: profile.group, duration: profile.duration,
            startTime: clock(), soundName: sound, state: .running
        )
        addInstance(instance)
    }

    func startAdHoc(duration: TimeInterval, soundName: String) {
        let instance = TimerInstance(
            id: UUID(), profileId: nil, displayName: formatDuration(duration),
            groupName: nil, duration: duration, startTime: clock(), soundName: soundName, state: .running
        )
        addInstance(instance)
    }

    func cancel(_ instance: TimerInstance) {
        instances.removeAll { $0.id == instance.id }
        scheduler.cancel(instanceId: instance.id)
        endActivity(for: instance, immediately: true)
    }

    func dismiss(_ instance: TimerInstance) {
        instances.removeAll { $0.id == instance.id }
    }

    // MARK: - Background Survival

    func handleBackground() {
        InstancePersistence.save(instances.filter { $0.state == .running })
    }

    func handleForeground() {
        let persisted = InstancePersistence.load()
        InstancePersistence.clear()
        let now = clock()
        for p in persisted {
            guard !instances.contains(where: { $0.id == p.id }) else { continue }
            let elapsed = now.timeIntervalSince(p.startTime)
            let state: InstanceState = elapsed >= p.duration ? .finished : .running
            let instance = TimerInstance(id: p.id, profileId: p.profileId,
                                         displayName: p.displayName, groupName: p.groupName,
                                         duration: p.duration, startTime: p.startTime,
                                         soundName: p.soundName, state: state)
            instances.append(instance)
        }
    }

    // MARK: - Internal (exposed for testing)

    func tickForTesting() { tick() }

    // MARK: - Private

    private var defaultSoundName: String {
        UserDefaults.standard.string(forKey: "defaultSoundName") ?? "default"
    }

    private func addInstance(_ instance: TimerInstance) {
        instances.append(instance)
        Task {
            try? await scheduler.schedule(instanceId: instance.id, displayName: instance.displayName,
                                          soundName: instance.soundName, delay: instance.duration)
        }
        startLiveActivity(for: instance)
    }

    private func startTick() {
        tickCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    private func tick() {
        let now = clock()
        for i in instances.indices where instances[i].state == .running {
            if now.timeIntervalSince(instances[i].startTime) >= instances[i].duration {
                markFinished(at: i)
            }
        }
    }

    private func markFinished(at index: Int) {
        guard instances[index].state == .running else { return }
        instances[index].state = .finished
        endActivity(for: instances[index], immediately: false)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let total = Int(duration)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s)
                     : String(format: "%d:%02d", m, s)
    }

    // MARK: - Live Activities

    private func startLiveActivity(for instance: TimerInstance) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = TimerAttributes(profileName: instance.displayName,
                                         groupName: instance.groupName,
                                         totalDuration: instance.duration)
        let state = TimerAttributes.ContentState(
            endDate: instance.startTime.addingTimeInterval(instance.duration),
            isFinished: false,
            totalDuration: instance.duration
        )
        do {
            let content = ActivityContent(state: state, staleDate: nil)
            let activity = try Activity<TimerAttributes>.request(attributes: attributes,
                                                                  content: content,
                                                                  pushType: nil)
            if let idx = instances.firstIndex(where: { $0.id == instance.id }) {
                instances[idx].activity = activity
            }
        } catch {
            // Live Activities unavailable — continue without
        }
    }

    private func endActivity(for instance: TimerInstance, immediately: Bool) {
        guard let activity = instance.activity else { return }
        Task {
            if immediately {
                await activity.end(ActivityContent(state: activity.content.state,
                                                   staleDate: nil),
                                   dismissalPolicy: .immediate)
            } else {
                let finishedState = TimerAttributes.ContentState(
                    endDate: instance.startTime.addingTimeInterval(instance.duration),
                    isFinished: true,
                    totalDuration: instance.duration
                )
                let finishedContent = ActivityContent(state: finishedState, staleDate: nil)
                await activity.update(finishedContent)
                try? await Task.sleep(for: .seconds(4))
                await activity.end(finishedContent, dismissalPolicy: .immediate)
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension TimerEngine: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in handleNotification(response.notification) }
        completionHandler()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        Task { @MainActor in handleNotification(notification) }
        completionHandler([.banner, .sound])
    }

    @MainActor
    private func handleNotification(_ notification: UNNotification) {
        guard let idString = notification.request.content.userInfo["instanceId"] as? String,
              let id = UUID(uuidString: idString),
              let idx = instances.firstIndex(where: { $0.id == id })
        else { return }
        markFinished(at: idx)
    }
}
