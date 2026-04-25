// Timers/Layout/ActiveInPlaceLayout.swift

struct ActiveInPlaceLayout: TimerListLayout {
    func sections(instances: [TimerInstance], groups: [String],
                  profiles: [TimerProfile]) -> [TimerSection] {
        var result: [TimerSection] = []

        for group in groups.sorted() {
            let groupProfiles = profiles
                .filter { $0.group == group }
                .sorted { $0.sortOrder < $1.sortOrder }
            guard !groupProfiles.isEmpty else { continue }

            var rows: [TimerRowItem] = []
            for profile in groupProfiles {
                rows.append(.profile(profile))
                let active = instances.filter { $0.profileId == profile.id }
                rows.append(contentsOf: active.map { .instance($0) })
            }
            result.append(TimerSection(id: "group-\(group)", title: group, rows: rows))
        }

        let ungrouped = profiles
            .filter { $0.group == nil }
            .sorted { $0.sortOrder < $1.sortOrder }
        if !ungrouped.isEmpty {
            var rows: [TimerRowItem] = []
            for profile in ungrouped {
                rows.append(.profile(profile))
                let active = instances.filter { $0.profileId == profile.id }
                rows.append(contentsOf: active.map { .instance($0) })
            }
            result.append(TimerSection(id: "ungrouped", title: nil, rows: rows))
        }

        let adHoc = instances.filter { $0.profileId == nil }
        if !adHoc.isEmpty {
            result.append(TimerSection(
                id: "adhoc",
                title: "Ad hoc",
                rows: adHoc.map { .instance($0) }
            ))
        }

        return result
    }
}
