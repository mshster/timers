// Timers/Layout/ActiveOnTopLayout.swift

struct ActiveOnTopLayout: TimerListLayout {
    func sections(instances: [TimerInstance], groups: [String],
                  profiles: [TimerProfile]) -> [TimerSection] {
        var result: [TimerSection] = []

        if !instances.isEmpty {
            result.append(TimerSection(
                id: "active",
                title: "Active",
                rows: instances.map { .instance($0) }
            ))
        }

        for group in groups.sorted() {
            let groupProfiles = profiles
                .filter { $0.group == group }
                .sorted { $0.sortOrder < $1.sortOrder }
            guard !groupProfiles.isEmpty else { continue }
            result.append(TimerSection(
                id: "group-\(group)",
                title: group,
                rows: groupProfiles.map { .profile($0) }
            ))
        }

        let ungrouped = profiles
            .filter { $0.group == nil }
            .sorted { $0.sortOrder < $1.sortOrder }
        if !ungrouped.isEmpty {
            result.append(TimerSection(
                id: "ungrouped",
                title: nil,
                rows: ungrouped.map { .profile($0) }
            ))
        }

        return result
    }
}
