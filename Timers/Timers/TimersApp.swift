//
//  TimersApp.swift
//  Timers
//
//  Created by David McKenzie on 4/25/26.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct TimersApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let engine = TimerEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(engine)
                .modelContainer(for: TimerProfile.self)
                .task {
                    guard !CommandLine.arguments.contains("--uitesting") else { return }
                    await requestNotificationPermission()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background: engine.handleBackground()
            case .active:     engine.handleForeground()
            default:          break
            }
        }
    }

    private func requestNotificationPermission() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }
}
