// Timers/Engine/InstancePersistence.swift
import Foundation

struct PersistedInstance: Codable {
    let id: UUID
    let profileId: UUID?
    let displayName: String
    let groupName: String?
    let duration: TimeInterval
    let startTime: Date
    let soundName: String
}

enum InstancePersistence {
    private static let fileName = "active-instances.json"

    private static var fileURL: URL {
        URL.applicationSupportDirectory.appending(path: fileName)
    }

    static func save(_ instances: [TimerInstance]) {
        let persisted = instances.map {
            PersistedInstance(id: $0.id, profileId: $0.profileId, displayName: $0.displayName,
                              groupName: $0.groupName, duration: $0.duration,
                              startTime: $0.startTime, soundName: $0.soundName)
        }
        guard let data = try? JSONEncoder().encode(persisted) else { return }
        try? data.write(to: fileURL)
    }

    static func load() -> [PersistedInstance] {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([PersistedInstance].self, from: data)
        else { return [] }
        return decoded
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
