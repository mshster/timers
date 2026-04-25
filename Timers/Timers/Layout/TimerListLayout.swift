// Timers/Layout/TimerListLayout.swift

protocol TimerListLayout {
    func sections(instances: [TimerInstance], groups: [String],
                  profiles: [TimerProfile]) -> [TimerSection]
}
