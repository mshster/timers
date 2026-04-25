// Timers/Views/SettingsView.swift
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @AppStorage("defaultSoundName") private var defaultSoundName: String = "default"
    @AppStorage("layoutMode") private var layoutModeRaw: String = LayoutMode.activeOnTop.rawValue

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    private var layoutMode: Binding<LayoutMode> {
        Binding(
            get: { LayoutMode(rawValue: layoutModeRaw) ?? .activeOnTop },
            set: { layoutModeRaw = $0.rawValue }
        )
    }

    var body: some View {
        Form {
            Section("Sound") {
                SoundPickerView(soundName: $defaultSoundName)
            }
            Section("Layout") {
                Picker("Timer layout", selection: layoutMode) {
                    ForEach(LayoutMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            if notificationStatus == .denied {
                Section {
                    HStack {
                        Image(systemName: "bell.slash")
                            .foregroundStyle(.orange)
                        Text("Notifications are disabled. Timers won't alert you in the background.")
                            .font(.caption)
                    }
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .task { await refreshNotificationStatus() }
    }

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = settings.authorizationStatus
    }
}
