// Timers/Views/ProfileEditorSheet.swift
import SwiftUI
import SwiftData

struct ProfileEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TimerProfile.sortOrder) private var allProfiles: [TimerProfile]

    let profile: TimerProfile?    // nil = create mode

    @State private var name: String = ""
    @State private var duration: TimeInterval = 180
    @State private var group: String = ""
    @State private var soundName: String = ""

    private var existingGroups: [String] {
        Array(Set(allProfiles.compactMap(\.group))).sorted()
    }

    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && duration > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Timer name", text: $name)
                }
                Section("Duration") {
                    CountdownPickerView(duration: $duration)
                        .frame(height: 180)
                }
                Section("Group (optional)") {
                    TextField("Group name", text: $group)
                    if !existingGroups.isEmpty {
                        ForEach(existingGroups, id: \.self) { g in
                            Button(g) { group = g }
                                .foregroundStyle(group == g ? .blue : .primary)
                        }
                    }
                }
                Section("Sound") {
                    SoundPickerView(soundName: $soundName, includeInheritOption: true)
                }
            }
            .navigationTitle(profile == nil ? "New Timer" : "Edit Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!isValid)
                }
            }
            .onAppear(perform: populateFields)
        }
    }

    private func populateFields() {
        guard let p = profile else { return }
        name = p.name
        duration = p.duration
        group = p.group ?? ""
        soundName = p.soundName ?? ""
    }

    private func save() {
        let groupValue: String? = group.trimmingCharacters(in: .whitespaces).isEmpty ? nil : group
        let soundValue: String? = soundName.isEmpty ? nil : soundName

        if let existing = profile {
            existing.name = name
            existing.duration = duration
            existing.group = groupValue
            existing.soundName = soundValue
        } else {
            let nextOrder = (allProfiles.map(\.sortOrder).max() ?? -1) + 1
            let newProfile = TimerProfile(name: name, duration: duration, group: groupValue,
                                          soundName: soundValue, sortOrder: nextOrder)
            modelContext.insert(newProfile)
        }
        dismiss()
    }
}
