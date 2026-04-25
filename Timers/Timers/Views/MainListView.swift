// Timers/Views/MainListView.swift
import SwiftUI
import SwiftData

struct MainListView: View {
    @Environment(TimerEngine.self) private var engine
    @Query(sort: \TimerProfile.sortOrder) private var profiles: [TimerProfile]
    @Environment(\.modelContext) private var modelContext

    @AppStorage("layoutMode") private var layoutModeRaw: String = LayoutMode.activeOnTop.rawValue
    @State private var showAdHocSheet = false
    @State private var showNewProfileSheet = false
    @State private var profileToEdit: TimerProfile? = nil

    private var layoutMode: LayoutMode {
        LayoutMode(rawValue: layoutModeRaw) ?? .activeOnTop
    }

    private var layout: any TimerListLayout {
        layoutMode == .activeOnTop ? ActiveOnTopLayout() : ActiveInPlaceLayout()
    }

    private var groups: [String] {
        Array(Set(profiles.compactMap(\.group))).sorted()
    }

    private var sections: [TimerSection] {
        layout.sections(instances: engine.instances, groups: groups, profiles: profiles)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sections) { section in
                    Section(header: section.title.map { Text($0) }) {
                        ForEach(section.rows, id: \.rowId) { row in
                            rowView(for: row)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Timers")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink { SettingsView() } label: {
                        Image(systemName: "gear")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button { showAdHocSheet = true } label: {
                            Image(systemName: "timer")
                        }
                        Button { showNewProfileSheet = true } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showAdHocSheet) {
                AdHocSheet()
            }
            .sheet(isPresented: $showNewProfileSheet) {
                ProfileEditorSheet(profile: nil)
            }
            .sheet(item: $profileToEdit) { profile in
                ProfileEditorSheet(profile: profile)
            }
        }
    }

    @ViewBuilder
    private func rowView(for row: TimerRowItem) -> some View {
        switch row {
        case .profile(let profile):
            TimerProfileRow(
                profile: profile,
                onStart: { engine.start(profile: profile) },
                onEdit: { profileToEdit = profile },
                onDuplicate: { duplicateProfile(profile) },
                onDelete: { deleteProfile(profile) }
            )
        case .instance(let instance):
            TimerInstanceRow(
                instance: instance,
                onCancel: { engine.cancel(instance) },
                onDismiss: { engine.dismiss(instance) }
            )
        }
    }

    private func duplicateProfile(_ profile: TimerProfile) {
        let copy = TimerProfile(name: profile.name + " copy", duration: profile.duration,
                                group: profile.group, soundName: profile.soundName,
                                sortOrder: profile.sortOrder + 1)
        modelContext.insert(copy)
    }

    private func deleteProfile(_ profile: TimerProfile) {
        modelContext.delete(profile)
    }
}

// MARK: - Helpers

extension TimerRowItem {
    var rowId: String {
        switch self {
        case .profile(let p): return "profile-\(p.id)"
        case .instance(let i): return "instance-\(i.id)"
        }
    }
}

