// TimersTests/MockNotificationScheduler.swift
import Foundation
@testable import Timers

final class MockNotificationScheduler: NotificationScheduler {
    struct ScheduleCall {
        let instanceId: UUID
        let displayName: String
        let soundName: String
        let delay: TimeInterval
    }

    private(set) var scheduleCalls: [ScheduleCall] = []
    private(set) var cancelledIds: [UUID] = []
    var authorizationResult = true

    func schedule(instanceId: UUID, displayName: String, soundName: String,
                  delay: TimeInterval) async throws {
        scheduleCalls.append(ScheduleCall(instanceId: instanceId, displayName: displayName,
                                          soundName: soundName, delay: delay))
    }

    func cancel(instanceId: UUID) {
        cancelledIds.append(instanceId)
    }

    func requestAuthorization() async throws -> Bool {
        authorizationResult
    }
}
