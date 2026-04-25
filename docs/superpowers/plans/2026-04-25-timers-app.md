# Timers App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a personal iOS timer app with named/grouped preset profiles, simultaneous ephemeral instances, no ad hoc auto-save, sound+banner completion, and Live Activities on the Dynamic Island and lock screen.

**Architecture:** `TimerEngine` (`@Observable` singleton) owns all running `TimerInstance` values and handles notification scheduling, background survival, and Live Activities. SwiftUI views observe the engine and dispatch actions to it. `TimerListLayout` protocol abstracts how sections are assembled from instances and profiles, making layout mode A↔B a one-property switch.

**Tech Stack:** Swift 5.9+, iOS 17+, SwiftUI, SwiftData, ActivityKit, UserNotifications, Combine (for `Timer.publish`), XCTest.

---

## File Structure

```
Timers/                                      # Xcode project root
├── Timers/                                  # App target
│   ├── TimersApp.swift                      # @main, environment setup, scene phase observer
│   ├── ContentView.swift                    # Root view — hosts MainListView + sheet state
│   ├── Models/
│   │   ├── TimerProfile.swift               # @Model SwiftData entity
│   │   ├── TimerInstance.swift              # In-memory ephemeral struct + InstanceState enum
│   │   ├── TimerSection.swift               # TimerSection + TimerRowItem used by layout protocol
│   │   ├── LayoutMode.swift                 # Enum: .activeOnTop / .activeInPlace
│   │   └── TimerAttributes.swift            # ActivityKit attributes (ALSO in widget target)
│   ├── Engine/
│   │   ├── TimerEngine.swift                # @Observable service: lifecycle, tick, background, notifications
│   │   ├── NotificationScheduler.swift      # Protocol + LiveNotificationScheduler implementation
│   │   └── InstancePersistence.swift        # JSON sidecar encode/decode for background survival
│   ├── Layout/
│   │   ├── TimerListLayout.swift            # Protocol definition
│   │   ├── ActiveOnTopLayout.swift          # Active instances float to top section
│   │   └── ActiveInPlaceLayout.swift        # Active instances inline within group rows
│   └── Views/
│       ├── MainListView.swift               # List assembled by TimerListLayout; nav bar buttons
│       ├── TimerProfileRow.swift            # Profile row: name, duration, tap=start, long-press menu
│       ├── TimerInstanceRow.swift           # Instance row: name, countdown, finished glow, dismiss
│       ├── AdHocSheet.swift                 # Ad hoc sheet: countdown picker + sound + start
│       ├── ProfileEditorSheet.swift         # Create/edit profile: name, duration, group, sound
│       ├── SettingsView.swift               # Default sound, layout mode, notification status
│       ├── SoundPickerView.swift            # Reusable sound picker list (used in 3 places)
│       └── CountdownPickerView.swift        # UIDatePicker(.countDownTimer) SwiftUI wrapper
├── TimersWidgetExtension/
│   └── TimersLiveActivity.swift             # ActivityConfiguration: compact, expanded, lock screen
├── TimersTests/
│   ├── MockNotificationScheduler.swift      # Test double: records calls, never touches UNUserNotification
│   ├── TimerEngineTests.swift               # TimerEngine lifecycle, tick, background, completion
│   ├── TimerListLayoutTests.swift           # ActiveOnTopLayout + ActiveInPlaceLayout section assembly
│   └── InstancePersistenceTests.swift       # Encode/decode round-trip, expired instance handling
└── TimersUITests/
    └── TimersUITests.swift                  # Ad hoc start flow; saved timer start from group
```

---

## Task 1: Create Xcode Project and Targets

**Files:**
- Create: `Timers/Timers.xcodeproj` (via Xcode GUI)
- Create: `Timers/TimersWidgetExtension/` (via Xcode "Add Target")

- [ ] **Step 1: Create the app project in Xcode**

  File → New → Project → iOS → App. Use these settings exactly:
  - Product Name: `Timers`
  - Bundle Identifier: `com.mshster.timers`
  - Interface: SwiftUI
  - Language: Swift
  - Storage: SwiftData
  - Include Tests: ✓ (creates both unit and UI test targets)

  Save to `/Users/davidmckenzie/git/timers/` — Xcode will create the `Timers/` subdirectory.

- [ ] **Step 2: Add the Widget Extension target**

  File → New → Target → Widget Extension.
  - Product Name: `TimersWidgetExtension`
  - Include Live Activity: ✓
  - Include Configuration App Intent: ✗

  When prompted "Activate TimersWidgetExtension scheme?", click Activate.

- [ ] **Step 3: Create directory structure**

  In the Xcode project navigator, create groups (folders) matching the file structure above:
  `Models/`, `Engine/`, `Layout/`, `Views/` under the `Timers` app target group.

- [ ] **Step 4: Verify the project builds clean**

  Select the `Timers` scheme, destination `iPhone 16 (iOS 17.x) Simulator`, then:
  ```bash
  cd /Users/davidmckenzie/git/timers
  xcodebuild -scheme Timers -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
  ```
  Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

  ```bash
  git add Timers/
  git commit -m "Add Xcode project scaffold with app + widget extension targets"
  ```

---

## Task 2: LayoutMode and TimerAttributes

**Files:**
- Create: `Timers/Timers/Models/LayoutMode.swift`
- Create: `Timers/Timers/Models/TimerAttributes.swift` (add to BOTH app and widget targets in Xcode)

- [ ] **Step 1: Create `LayoutMode.swift`**

  ```swift
  // Timers/Models/LayoutMode.swift
  enum LayoutMode: String, CaseIterable {
      case activeOnTop
      case activeInPlace

      var displayName: String {
          switch self {
          case .activeOnTop: return "Active timers on top"
          case .activeInPlace: return "Active timers in-place"
          }
      }
  }
  ```

- [ ] **Step 2: Create `TimerAttributes.swift`**

  ```swift
  // Timers/Models/TimerAttributes.swift
  import ActivityKit
  import Foundation

  struct TimerAttributes: ActivityAttributes {
      struct ContentState: Codable, Hashable {
          var endDate: Date
          var isFinished: Bool
          var totalDuration: TimeInterval
      }

      let profileName: String
      let totalDuration: TimeInterval
  }
  ```

  In Xcode's File Inspector (right panel), add this file to the `TimersWidgetExtension` target as well as the app target — check both boxes under "Target Membership".

- [ ] **Step 3: Verify both targets compile**

  ```bash
  xcodebuild -scheme Timers -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -3
  xcodebuild -scheme TimersWidgetExtension -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -3
  ```
  Expected: `** BUILD SUCCEEDED **` for both.

- [ ] **Step 4: Commit**

  ```bash
  git add Timers/Timers/Models/LayoutMode.swift Timers/Timers/Models/TimerAttributes.swift
  git commit -m "Add LayoutMode enum and shared TimerAttributes ActivityKit type"
  ```

---

## Task 3: TimerProfile (SwiftData Model)

**Files:**
- Create: `Timers/Timers/Models/TimerProfile.swift`

- [ ] **Step 1: Create `TimerProfile.swift`**

  ```swift
  // Timers/Models/TimerProfile.swift
  import Foundation
  import SwiftData

  @Model
  final class TimerProfile {
      var id: UUID
      var name: String
      var duration: TimeInterval
      var group: String?
      var soundName: String?
      var sortOrder: Int

      init(name: String, duration: TimeInterval, group: String? = nil,
           soundName: String? = nil, sortOrder: Int = 0) {
          self.id = UUID()
          self.name = name
          self.duration = duration
          self.group = group
          self.soundName = soundName
          self.sortOrder = sortOrder
      }
  }
  ```

- [ ] **Step 2: Build to confirm SwiftData compiles**

  ```bash
  xcodebuild -scheme Timers -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -3
  ```
  Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

  ```bash
  git add Timers/Timers/Models/TimerProfile.swift
  git commit -m "Add TimerProfile SwiftData model"
  ```

---

## Task 4: TimerInstance, TimerSection, and TimerListLayout Types

**Files:**
- Create: `Timers/Timers/Models/TimerInstance.swift`
- Create: `Timers/Timers/Models/TimerSection.swift`
- Create: `Timers/Timers/Layout/TimerListLayout.swift`
- Create: `Timers/TimersTests/TimerListLayoutTests.swift`

- [ ] **Step 1: Write failing tests for `TimerSection` and `TimerRowItem`**

  Create `Timers/TimersTests/TimerListLayoutTests.swift`:

  ```swift
  import XCTest
  @testable import Timers

  final class TimerListLayoutTests: XCTestCase {

      private func makeProfile(name: String, group: String?, sortOrder: Int = 0) -> TimerProfile {
          let p = TimerProfile(name: name, duration: 60, group: group, sortOrder: sortOrder)
          return p
      }

      private func makeInstance(profileId: UUID?, displayName: String = "Test") -> TimerInstance {
          TimerInstance(id: UUID(), profileId: profileId, displayName: displayName,
                        duration: 60, startTime: Date(), soundName: "default", state: .running)
      }

      func test_activeOnTop_noInstances_oneGroup() {
          let profile = makeProfile(name: "Earl Grey", group: "Tea")
          let layout = ActiveOnTopLayout()
          let sections = layout.sections(instances: [], groups: ["Tea"], profiles: [profile])
          XCTAssertEqual(sections.count, 1)
          XCTAssertEqual(sections[0].title, "Tea")
          XCTAssertEqual(sections[0].rows.count, 1)
      }

      func test_activeOnTop_withInstance_activeFloatsToTop() {
          let profile = makeProfile(name: "Earl Grey", group: "Tea")
          let instance = makeInstance(profileId: profile.id, displayName: "Earl Grey")
          let layout = ActiveOnTopLayout()
          let sections = layout.sections(instances: [instance], groups: ["Tea"], profiles: [profile])
          XCTAssertEqual(sections.count, 2)
          XCTAssertEqual(sections[0].title, "Active")
          if case .instance(let i) = sections[0].rows[0] {
              XCTAssertEqual(i.id, instance.id)
          } else {
              XCTFail("First row of Active section should be an instance")
          }
          XCTAssertEqual(sections[1].title, "Tea")
      }

      func test_activeOnTop_adHocInstance_appearsInActiveSection() {
          let instance = makeInstance(profileId: nil, displayName: "5:00")
          let layout = ActiveOnTopLayout()
          let sections = layout.sections(instances: [instance], groups: [], profiles: [])
          XCTAssertEqual(sections.count, 1)
          XCTAssertEqual(sections[0].title, "Active")
      }

      func test_activeOnTop_ungroupedProfiles_appearsLastWithNilTitle() {
          let profile = makeProfile(name: "Pasta", group: nil)
          let layout = ActiveOnTopLayout()
          let sections = layout.sections(instances: [], groups: [], profiles: [profile])
          XCTAssertEqual(sections.count, 1)
          XCTAssertNil(sections[0].title)
      }

      func test_activeInPlace_instanceAppearsAfterProfile() {
          let profile = makeProfile(name: "Earl Grey", group: "Tea")
          let instance = makeInstance(profileId: profile.id, displayName: "Earl Grey")
          let layout = ActiveInPlaceLayout()
          let sections = layout.sections(instances: [instance], groups: ["Tea"], profiles: [profile])
          XCTAssertEqual(sections.count, 1)
          XCTAssertEqual(sections[0].rows.count, 2)
          if case .profile(let p) = sections[0].rows[0] {
              XCTAssertEqual(p.id, profile.id)
          } else { XCTFail("First row should be profile") }
          if case .instance(let i) = sections[0].rows[1] {
              XCTAssertEqual(i.id, instance.id)
          } else { XCTFail("Second row should be instance") }
      }

      func test_activeInPlace_adHocInstanceAppearsInAdHocSection() {
          let instance = makeInstance(profileId: nil, displayName: "5:00")
          let layout = ActiveInPlaceLayout()
          let sections = layout.sections(instances: [instance], groups: [], profiles: [])
          XCTAssertEqual(sections.count, 1)
          XCTAssertEqual(sections[0].id, "adhoc")
      }
  }
  ```

- [ ] **Step 2: Run tests — verify they fail to compile (types not defined yet)**

  ```bash
  xcodebuild test -scheme Timers -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:TimersTests/TimerListLayoutTests 2>&1 | tail -10
  ```
  Expected: build error — `TimerInstance`, `ActiveOnTopLayout`, etc. not found.

- [ ] **Step 3: Create `TimerInstance.swift`**

  ```swift
  // Timers/Models/TimerInstance.swift
  import Foundation
  import ActivityKit

  enum InstanceState: Codable, Equatable {
      case running
      case finished
  }

  struct TimerInstance: Identifiable {
      let id: UUID
      let profileId: UUID?
      let displayName: String
      let duration: TimeInterval
      let startTime: Date
      let soundName: String
      var state: InstanceState
      var activity: Activity<TimerAttributes>?

      var isFinished: Bool { state == .finished }

      var remainingSeconds: TimeInterval {
          max(0, duration - Date().timeIntervalSince(startTime))
      }
  }
  ```

- [ ] **Step 4: Create `TimerSection.swift`**

  ```swift
  // Timers/Models/TimerSection.swift
  import Foundation

  enum TimerRowItem {
      case profile(TimerProfile)
      case instance(TimerInstance)
  }

  struct TimerSection: Identifiable {
      let id: String
      let title: String?
      let rows: [TimerRowItem]
  }
  ```

- [ ] **Step 5: Create `TimerListLayout.swift`**

  ```swift
  // Timers/Layout/TimerListLayout.swift

  protocol TimerListLayout {
      func sections(instances: [TimerInstance], groups: [String],
                    profiles: [TimerProfile]) -> [TimerSection]
  }
  ```

- [ ] **Step 6: Create `ActiveOnTopLayout.swift`**

  ```swift
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
  ```

- [ ] **Step 7: Create `ActiveInPlaceLayout.swift`**

  ```swift
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
  ```

- [ ] **Step 8: Run tests — verify they pass**

  ```bash
  xcodebuild test -scheme Timers -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:TimersTests/TimerListLayoutTests 2>&1 | grep -E "Test Suite|PASS|FAIL|error:"
  ```
  Expected: all 6 tests pass.

- [ ] **Step 9: Commit**

  ```bash
  git add Timers/Timers/Models/TimerInstance.swift \
          Timers/Timers/Models/TimerSection.swift \
          Timers/Timers/Layout/ \
          Timers/TimersTests/TimerListLayoutTests.swift
  git commit -m "Add TimerInstance, TimerSection, TimerListLayout protocol, and both layout implementations"
  ```

---

## Task 5: NotificationScheduler Protocol and InstancePersistence

**Files:**
- Create: `Timers/Timers/Engine/NotificationScheduler.swift`
- Create: `Timers/Timers/Engine/InstancePersistence.swift`
- Create: `Timers/TimersTests/MockNotificationScheduler.swift`
- Create: `Timers/TimersTests/InstancePersistenceTests.swift`

- [ ] **Step 1: Write failing tests for `InstancePersistence`**

  Create `Timers/TimersTests/InstancePersistenceTests.swift`:

  ```swift
  import XCTest
  @testable import Timers

  final class InstancePersistenceTests: XCTestCase {

      override func tearDown() {
          super.tearDown()
          InstancePersistence.clear()
      }

      func test_roundTrip_preservesAllFields() throws {
          let start = Date(timeIntervalSinceReferenceDate: 1000000)
          let instance = TimerInstance(
              id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
              profileId: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
              displayName: "Earl Grey",
              duration: 180,
              startTime: start,
              soundName: "chime",
              state: .running
          )

          InstancePersistence.save([instance])
          let loaded = InstancePersistence.load()

          XCTAssertEqual(loaded.count, 1)
          XCTAssertEqual(loaded[0].id, instance.id)
          XCTAssertEqual(loaded[0].profileId, instance.profileId)
          XCTAssertEqual(loaded[0].displayName, "Earl Grey")
          XCTAssertEqual(loaded[0].duration, 180)
          XCTAssertEqual(loaded[0].startTime.timeIntervalSinceReferenceDate,
                         start.timeIntervalSinceReferenceDate, accuracy: 0.001)
          XCTAssertEqual(loaded[0].soundName, "chime")
      }

      func test_load_returnsEmpty_whenNoFile() {
          InstancePersistence.clear()
          XCTAssertEqual(InstancePersistence.load().count, 0)
      }

      func test_save_overwritesPreviousFile() {
          let a = TimerInstance(id: UUID(), profileId: nil, displayName: "A",
                                duration: 60, startTime: Date(), soundName: "default", state: .running)
          let b = TimerInstance(id: UUID(), profileId: nil, displayName: "B",
                                duration: 120, startTime: Date(), soundName: "default", state: .running)
          InstancePersistence.save([a])
          InstancePersistence.save([b])
          let loaded = InstancePersistence.load()
          XCTAssertEqual(loaded.count, 1)
          XCTAssertEqual(loaded[0].displayName, "B")
      }
  }
  ```

- [ ] **Step 2: Run tests — verify they fail to compile**

  ```bash
  xcodebuild test -scheme Timers -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:TimersTests/InstancePersistenceTests 2>&1 | tail -5
  ```
  Expected: compile error — `InstancePersistence` not found.

- [ ] **Step 3: Create `InstancePersistence.swift`**

  ```swift
  // Timers/Engine/InstancePersistence.swift
  import Foundation

  struct PersistedInstance: Codable {
      let id: UUID
      let profileId: UUID?
      let displayName: String
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
                                duration: $0.duration, startTime: $0.startTime, soundName: $0.soundName)
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
  ```

- [ ] **Step 4: Run tests — verify they pass**

  ```bash
  xcodebuild test -scheme Timers -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:TimersTests/InstancePersistenceTests 2>&1 | grep -E "Test Suite|PASS|FAIL|error:"
  ```
  Expected: 3 tests pass.

- [ ] **Step 5: Create `NotificationScheduler.swift`**

  ```swift
  // Timers/Engine/NotificationScheduler.swift
  import Foundation
  import UserNotifications

  protocol NotificationScheduler {
      func schedule(instanceId: UUID, displayName: String, soundName: String,
                    delay: TimeInterval) async throws
      func cancel(instanceId: UUID)
      func requestAuthorization() async throws -> Bool
  }

  final class LiveNotificationScheduler: NotificationScheduler {
      func schedule(instanceId: UUID, displayName: String, soundName: String,
                    delay: TimeInterval) async throws {
          let content = UNMutableNotificationContent()
          content.title = displayName
          content.body = "Timer finished"
          content.sound = soundName == "default"
              ? .default
              : UNNotificationSound(named: UNNotificationSoundName(rawValue: soundName + ".caf"))
          content.userInfo = ["instanceId": instanceId.uuidString]

          let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(delay, 1), repeats: false)
          let request = UNNotificationRequest(identifier: instanceId.uuidString,
                                              content: content, trigger: trigger)
          try await UNUserNotificationCenter.current().add(request)
      }

      func cancel(instanceId: UUID) {
          let id = instanceId.uuidString
          UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
          UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
      }

      func requestAuthorization() async throws -> Bool {
          try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
      }
  }
  ```

- [ ] **Step 6: Create `MockNotificationScheduler.swift`** (test target only — do not add to app target)

  ```swift
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
  ```

- [ ] **Step 7: Build to confirm no compile errors**

  ```bash
  xcodebuild -scheme Timers -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -3
  ```
  Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: Commit**

  ```bash
  git add Timers/Timers/Engine/NotificationScheduler.swift \
          Timers/Timers/Engine/InstancePersistence.swift \
          Timers/TimersTests/MockNotificationScheduler.swift \
          Timers/TimersTests/InstancePersistenceTests.swift
  git commit -m "Add NotificationScheduler protocol, LiveNotificationScheduler, InstancePersistence"
  ```

---

## Task 6: TimerEngine — Core Lifecycle and Tick

**Files:**
- Create: `Timers/Timers/Engine/TimerEngine.swift`
- Create: `Timers/TimersTests/TimerEngineTests.swift`

- [ ] **Step 1: Write failing tests**

  Create `Timers/TimersTests/TimerEngineTests.swift`:

  ```swift
  import XCTest
  @testable import Timers

  @MainActor
  final class TimerEngineTests: XCTestCase {

      private var scheduler: MockNotificationScheduler!
      private var engine: TimerEngine!
      private var fixedNow: Date!

      override func setUp() {
          super.setUp()
          fixedNow = Date(timeIntervalSinceReferenceDate: 1_000_000)
          scheduler = MockNotificationScheduler()
          engine = TimerEngine(scheduler: scheduler, clock: { [weak self] in self!.fixedNow })
      }

      override func tearDown() {
          engine = nil
          scheduler = nil
          InstancePersistence.clear()
          super.tearDown()
      }

      private func makeProfile(duration: TimeInterval = 60, sound: String? = nil) -> TimerProfile {
          TimerProfile(name: "Test", duration: duration, soundName: sound)
      }

      // MARK: start(profile:)

      func test_start_addsInstance() {
          let profile = makeProfile()
          engine.start(profile: profile)
          XCTAssertEqual(engine.instances.count, 1)
          XCTAssertEqual(engine.instances[0].profileId, profile.id)
          XCTAssertEqual(engine.instances[0].displayName, "Test")
          XCTAssertEqual(engine.instances[0].duration, 60)
          XCTAssertEqual(engine.instances[0].state, .running)
      }

      func test_start_schedulesNotification() async {
          let profile = makeProfile(duration: 120)
          engine.start(profile: profile)
          try? await Task.sleep(for: .milliseconds(100))
          XCTAssertEqual(scheduler.scheduleCalls.count, 1)
          XCTAssertEqual(scheduler.scheduleCalls[0].delay, 120)
      }

      func test_start_usesProfileSound_whenSet() async {
          let profile = makeProfile(sound: "chime")
          engine.start(profile: profile)
          try? await Task.sleep(for: .milliseconds(100))
          XCTAssertEqual(scheduler.scheduleCalls[0].soundName, "chime")
      }

      func test_start_usesDefaultSound_whenProfileSoundNil() async {
          let profile = makeProfile(sound: nil)
          engine.start(profile: profile)
          try? await Task.sleep(for: .milliseconds(100))
          XCTAssertEqual(scheduler.scheduleCalls[0].soundName, "default")
      }

      func test_startAdHoc_addsInstanceWithNilProfileId() {
          engine.startAdHoc(duration: 300, soundName: "default")
          XCTAssertEqual(engine.instances.count, 1)
          XCTAssertNil(engine.instances[0].profileId)
          XCTAssertEqual(engine.instances[0].displayName, "5:00")
      }

      func test_startAdHoc_displayName_hoursMinutesSeconds() {
          engine.startAdHoc(duration: 3661, soundName: "default")
          XCTAssertEqual(engine.instances[0].displayName, "1:01:01")
      }

      // MARK: cancel(_:)

      func test_cancel_removesInstance() {
          engine.start(profile: makeProfile())
          let instance = engine.instances[0]
          engine.cancel(instance)
          XCTAssertTrue(engine.instances.isEmpty)
      }

      func test_cancel_callsSchedulerCancel() {
          engine.start(profile: makeProfile())
          let instance = engine.instances[0]
          engine.cancel(instance)
          XCTAssertEqual(scheduler.cancelledIds.count, 1)
          XCTAssertEqual(scheduler.cancelledIds[0], instance.id)
      }

      // MARK: dismiss(_:)

      func test_dismiss_removesFinishedInstance() {
          engine.start(profile: makeProfile())
          var instance = engine.instances[0]
          // Simulate finish by advancing clock past duration
          fixedNow = fixedNow.addingTimeInterval(61)
          engine.tickForTesting()
          instance = engine.instances[0]
          XCTAssertEqual(instance.state, .finished)
          engine.dismiss(instance)
          XCTAssertTrue(engine.instances.isEmpty)
      }

      // MARK: tick

      func test_tick_marksInstanceFinished_whenDurationElapsed() {
          engine.start(profile: makeProfile(duration: 60))
          fixedNow = fixedNow.addingTimeInterval(61)
          engine.tickForTesting()
          XCTAssertEqual(engine.instances[0].state, .finished)
      }

      func test_tick_doesNotMarkFinished_beforeDuration() {
          engine.start(profile: makeProfile(duration: 60))
          fixedNow = fixedNow.addingTimeInterval(30)
          engine.tickForTesting()
          XCTAssertEqual(engine.instances[0].state, .running)
      }

      func test_multipleInstances_canRunSimultaneously() {
          let p1 = makeProfile(duration: 60)
          let p2 = makeProfile(duration: 120)
          engine.start(profile: p1)
          engine.start(profile: p2)
          XCTAssertEqual(engine.instances.count, 2)
          fixedNow = fixedNow.addingTimeInterval(61)
          engine.tickForTesting()
          XCTAssertEqual(engine.instances.filter { $0.state == .finished }.count, 1)
          XCTAssertEqual(engine.instances.filter { $0.state == .running }.count, 1)
      }
  }
  ```

- [ ] **Step 2: Run tests — verify they fail to compile**

  ```bash
  xcodebuild test -scheme Timers -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:TimersTests/TimerEngineTests 2>&1 | tail -5
  ```
  Expected: compile error — `TimerEngine` not found.

- [ ] **Step 3: Create `TimerEngine.swift`**

  ```swift
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
              duration: profile.duration, startTime: clock(), soundName: sound, state: .running
          )
          addInstance(instance)
      }

      func startAdHoc(duration: TimeInterval, soundName: String) {
          let instance = TimerInstance(
              id: UUID(), profileId: nil, displayName: formatDuration(duration),
              duration: duration, startTime: clock(), soundName: soundName, state: .running
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
                                           displayName: p.displayName, duration: p.duration,
                                           startTime: p.startTime, soundName: p.soundName, state: state)
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
  ```

- [ ] **Step 4: Run tests — verify they pass**

  ```bash
  xcodebuild test -scheme Timers -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:TimersTests/TimerEngineTests 2>&1 | grep -E "Test Suite|PASS|FAIL|error:"
  ```
  Expected: all tests pass.

- [ ] **Step 5: Commit**

  ```bash
  git add Timers/Timers/Engine/TimerEngine.swift Timers/TimersTests/TimerEngineTests.swift
  git commit -m "Add TimerEngine with lifecycle, tick, and notification scheduling"
  ```

---

## Task 7: TimerEngine — Background Survival Tests

**Files:**
- Modify: `Timers/TimersTests/TimerEngineTests.swift`

- [ ] **Step 1: Add background survival tests to `TimerEngineTests.swift`**

  Append these test methods inside the `TimerEngineTests` class:

  ```swift
  // MARK: Background survival

  func test_handleBackground_persistsRunningInstances() {
      engine.start(profile: makeProfile(duration: 60))
      engine.handleBackground()
      let loaded = InstancePersistence.load()
      XCTAssertEqual(loaded.count, 1)
      XCTAssertEqual(loaded[0].duration, 60)
  }

  func test_handleBackground_doesNotPersistFinishedInstances() {
      engine.start(profile: makeProfile(duration: 60))
      fixedNow = fixedNow.addingTimeInterval(61)
      engine.tickForTesting()
      engine.handleBackground()
      XCTAssertEqual(InstancePersistence.load().count, 0)
  }

  func test_handleForeground_reconstructsRunningInstance() {
      engine.start(profile: makeProfile(duration: 120))
      let original = engine.instances[0]
      engine.handleBackground()

      // Simulate fresh engine (new foreground session)
      engine = TimerEngine(scheduler: scheduler, clock: { [weak self] in self!.fixedNow })
      engine.handleForeground()

      XCTAssertEqual(engine.instances.count, 1)
      XCTAssertEqual(engine.instances[0].id, original.id)
      XCTAssertEqual(engine.instances[0].state, .running)
  }

  func test_handleForeground_marksExpiredInstanceFinished() {
      engine.start(profile: makeProfile(duration: 60))
      engine.handleBackground()

      fixedNow = fixedNow.addingTimeInterval(90)
      engine = TimerEngine(scheduler: scheduler, clock: { [weak self] in self!.fixedNow })
      engine.handleForeground()

      XCTAssertEqual(engine.instances.count, 1)
      XCTAssertEqual(engine.instances[0].state, .finished)
  }

  func test_handleForeground_ignoresDuplicateIds() {
      engine.start(profile: makeProfile(duration: 120))
      engine.handleBackground()
      // Call handleForeground twice — should not double-add
      engine.handleForeground()
      engine.handleForeground()
      XCTAssertEqual(engine.instances.count, 1)
  }
  ```

- [ ] **Step 2: Run new tests — verify they pass**

  ```bash
  xcodebuild test -scheme Timers -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:TimersTests/TimerEngineTests 2>&1 | grep -E "Test Suite|PASS|FAIL|error:"
  ```
  Expected: all tests pass (the 4 new ones plus the original set).

- [ ] **Step 3: Commit**

  ```bash
  git add Timers/TimersTests/TimerEngineTests.swift
  git commit -m "Add TimerEngine background survival tests"
  ```

---

## Task 8: App Entry Point, Environment, and Scene Phase Observation

**Files:**
- Modify: `Timers/Timers/TimersApp.swift`
- Modify: `Timers/Timers/ContentView.swift`

- [ ] **Step 1: Replace `TimersApp.swift`**

  ```swift
  // Timers/TimersApp.swift
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
          }
          .onChange(of: scenePhase) { _, newPhase in
              switch newPhase {
              case .background: engine.handleBackground()
              case .active:     engine.handleForeground()
              default:          break
              }
          }
      }
  }
  ```

- [ ] **Step 2: Replace `ContentView.swift`**

  ```swift
  // Timers/ContentView.swift
  import SwiftUI

  struct ContentView: View {
      @Environment(TimerEngine.self) private var engine

      var body: some View {
          MainListView()
      }
  }
  ```

- [ ] **Step 3: Create a stub `MainListView.swift` so it compiles**

  ```swift
  // Timers/Views/MainListView.swift
  import SwiftUI

  struct MainListView: View {
      var body: some View {
          NavigationStack {
              Text("Timers")
                  .navigationTitle("Timers")
          }
      }
  }
  ```

- [ ] **Step 4: Request notification authorization on first launch — add to `TimersApp.swift`**

  Add a `.task` modifier on the `ContentView()`:

  ```swift
  ContentView()
      .environment(engine)
      .modelContainer(for: TimerProfile.self)
      .task { await requestNotificationPermission() }
  ```

  Add the helper inside the `TimersApp` struct:

  ```swift
  private func requestNotificationPermission() async {
      _ = try? await UNUserNotificationCenter.current()
          .requestAuthorization(options: [.alert, .sound])
  }
  ```

- [ ] **Step 5: Build and run on simulator**

  ```bash
  xcodebuild -scheme Timers -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -3
  ```
  Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

  ```bash
  git add Timers/Timers/TimersApp.swift Timers/Timers/ContentView.swift \
          Timers/Timers/Views/MainListView.swift
  git commit -m "Wire app entry point: TimerEngine environment, SwiftData container, scene phase observer"
  ```

---

## Task 9: Reusable UI Components — CountdownPickerView and SoundPickerView

**Files:**
- Create: `Timers/Timers/Views/CountdownPickerView.swift`
- Create: `Timers/Timers/Views/SoundPickerView.swift`

The sound list uses `UNNotificationSound`. Bundle audio files as `.caf` files in the app target — place them in `Timers/Timers/Resources/Sounds/`. The list below uses names that match files you add to the bundle. `"default"` always maps to `UNNotificationSound.default`.

- [ ] **Step 1: Create `CountdownPickerView.swift`**

  ```swift
  // Timers/Views/CountdownPickerView.swift
  import SwiftUI
  import UIKit

  struct CountdownPickerView: UIViewRepresentable {
      @Binding var duration: TimeInterval

      func makeUIView(context: Context) -> UIDatePicker {
          let picker = UIDatePicker()
          picker.datePickerMode = .countDownTimer
          picker.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)),
                           for: .valueChanged)
          return picker
      }

      func updateUIView(_ uiView: UIDatePicker, context: Context) {
          uiView.countDownDuration = duration
      }

      func makeCoordinator() -> Coordinator { Coordinator(self) }

      final class Coordinator: NSObject {
          var parent: CountdownPickerView
          init(_ parent: CountdownPickerView) { self.parent = parent }

          @objc func changed(_ sender: UIDatePicker) {
              parent.duration = sender.countDownDuration
          }
      }
  }
  ```

- [ ] **Step 2: Create `SoundPickerView.swift`**

  ```swift
  // Timers/Views/SoundPickerView.swift
  import SwiftUI
  import AVFoundation

  struct SoundOption: Identifiable, Hashable {
      let id: String          // "" means use global default; "default" means UNNotificationSound.default
      let displayName: String
  }

  enum AvailableSounds {
      // "default" → UNNotificationSound.default
      // Add entries here as you add .caf files to the bundle.
      static let all: [SoundOption] = [
          SoundOption(id: "default", displayName: "Default"),
          // SoundOption(id: "chime", displayName: "Chime"),
          // SoundOption(id: "bell", displayName: "Bell"),
      ]

      // Shown in profile editor; includes "Use default (inherit from Settings)"
      static let withInherit: [SoundOption] = [
          SoundOption(id: "", displayName: "Use default"),
      ] + all
  }

  struct SoundPickerView: View {
      /// Binding to a sound name: "" = inherit global default, "default" = explicit default, other = named file
      @Binding var soundName: String
      var includeInheritOption: Bool = false

      private var options: [SoundOption] {
          includeInheritOption ? AvailableSounds.withInherit : AvailableSounds.all
      }

      var body: some View {
          Picker("Sound", selection: $soundName) {
              ForEach(options) { option in
                  Text(option.displayName).tag(option.id)
              }
          }
      }
  }
  ```

- [ ] **Step 3: Build**

  ```bash
  xcodebuild -scheme Timers -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -3
  ```
  Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

  ```bash
  git add Timers/Timers/Views/CountdownPickerView.swift Timers/Timers/Views/SoundPickerView.swift
  git commit -m "Add CountdownPickerView (UIDatePicker wrapper) and SoundPickerView"
  ```

---

## Task 10: TimerProfileRow and TimerInstanceRow

**Files:**
- Create: `Timers/Timers/Views/TimerProfileRow.swift`
- Create: `Timers/Timers/Views/TimerInstanceRow.swift`

- [ ] **Step 1: Create `TimerProfileRow.swift`**

  ```swift
  // Timers/Views/TimerProfileRow.swift
  import SwiftUI

  struct TimerProfileRow: View {
      let profile: TimerProfile
      let onStart: () -> Void
      let onEdit: () -> Void
      let onDuplicate: () -> Void
      let onDelete: () -> Void

      var body: some View {
          Button(action: onStart) {
              HStack {
                  VStack(alignment: .leading, spacing: 2) {
                      Text(profile.name)
                          .font(.body)
                      Text(formatDuration(profile.duration))
                          .font(.caption)
                          .foregroundStyle(.secondary)
                  }
                  Spacer()
                  Image(systemName: "play.fill")
                      .foregroundStyle(.blue)
              }
          }
          .buttonStyle(.plain)
          .contextMenu {
              Button("Edit", systemImage: "pencil", action: onEdit)
              Button("Duplicate", systemImage: "plus.square.on.square", action: onDuplicate)
              Divider()
              Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
          }
      }

      private func formatDuration(_ duration: TimeInterval) -> String {
          let total = Int(duration)
          let h = total / 3600
          let m = (total % 3600) / 60
          let s = total % 60
          if h > 0 { return String(format: "%d hr %02d min", h, m) }
          if s > 0 { return String(format: "%d min %02d sec", m, s) }
          return String(format: "%d min", m)
      }
  }
  ```

- [ ] **Step 2: Create `TimerInstanceRow.swift`**

  ```swift
  // Timers/Views/TimerInstanceRow.swift
  import SwiftUI

  struct TimerInstanceRow: View {
      let instance: TimerInstance
      let onCancel: () -> Void
      let onDismiss: () -> Void

      var body: some View {
          HStack {
              VStack(alignment: .leading, spacing: 2) {
                  Text(instance.displayName)
                      .font(.body)
                  if instance.isFinished {
                      Text("Finished")
                          .font(.caption)
                          .foregroundStyle(.green)
                  }
              }
              Spacer()
              if instance.isFinished {
                  Button("Dismiss", action: onDismiss)
                      .buttonStyle(.borderless)
                      .foregroundStyle(.secondary)
              } else {
                  CountdownText(instance: instance)
                  Button(action: onCancel) {
                      Image(systemName: "xmark.circle.fill")
                          .foregroundStyle(.secondary)
                  }
                  .buttonStyle(.plain)
              }
          }
          .listRowBackground(instance.isFinished ? Color.green.opacity(0.12) : nil)
      }
  }

  private struct CountdownText: View {
      let instance: TimerInstance
      // Recompute every second via a TimelineView
      var body: some View {
          TimelineView(.periodic(from: .now, by: 1)) { _ in
              Text(formatRemaining(instance.remainingSeconds))
                  .font(.system(.body, design: .monospaced))
                  .monospacedDigit()
          }
      }

      private func formatRemaining(_ seconds: TimeInterval) -> String {
          let total = max(0, Int(seconds))
          let h = total / 3600
          let m = (total % 3600) / 60
          let s = total % 60
          return h > 0 ? String(format: "%d:%02d:%02d", h, m, s)
                       : String(format: "%d:%02d", m, s)
      }
  }
  ```

  Note: `TimelineView(.periodic(from:by:))` drives countdown updates without needing the engine tick — it keeps the countdown accurate even between engine tick fires.

- [ ] **Step 3: Build**

  ```bash
  xcodebuild -scheme Timers -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -3
  ```
  Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

  ```bash
  git add Timers/Timers/Views/TimerProfileRow.swift Timers/Timers/Views/TimerInstanceRow.swift
  git commit -m "Add TimerProfileRow and TimerInstanceRow"
  ```

---

## Task 11: MainListView

**Files:**
- Modify: `Timers/Timers/Views/MainListView.swift`

- [ ] **Step 1: Replace `MainListView.swift`**

  ```swift
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
  ```

- [ ] **Step 2: Build and run on simulator**

  ```bash
  xcodebuild -scheme Timers -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -3
  ```
  Expected: `** BUILD SUCCEEDED **`. Boot the simulator and verify the list screen appears with the nav bar buttons.

- [ ] **Step 3: Commit**

  ```bash
  git add Timers/Timers/Views/MainListView.swift
  git commit -m "Implement MainListView with layout-protocol-driven sections, nav bar, and sheet bindings"
  ```

---

## Task 12: AdHocSheet

**Files:**
- Create: `Timers/Timers/Views/AdHocSheet.swift`

- [ ] **Step 1: Create `AdHocSheet.swift`**

  ```swift
  // Timers/Views/AdHocSheet.swift
  import SwiftUI

  struct AdHocSheet: View {
      @Environment(TimerEngine.self) private var engine
      @Environment(\.dismiss) private var dismiss
      @AppStorage("defaultSoundName") private var defaultSoundName: String = "default"

      @State private var duration: TimeInterval = 60
      @State private var soundName: String = ""   // populated from defaultSoundName on appear

      var body: some View {
          NavigationStack {
              Form {
                  Section {
                      CountdownPickerView(duration: $duration)
                          .frame(height: 180)
                  }
                  Section("Sound") {
                      SoundPickerView(soundName: $soundName)
                  }
              }
              .navigationTitle("Quick Timer")
              .navigationBarTitleDisplayMode(.inline)
              .toolbar {
                  ToolbarItem(placement: .cancellationAction) {
                      Button("Cancel") { dismiss() }
                  }
                  ToolbarItem(placement: .confirmationAction) {
                      Button("Start") {
                          engine.startAdHoc(duration: duration, soundName: soundName)
                          dismiss()
                      }
                      .disabled(duration <= 0)
                  }
              }
              .onAppear { soundName = defaultSoundName }
          }
      }
  }
  ```

- [ ] **Step 2: Build**

  ```bash
  xcodebuild -scheme Timers -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -3
  ```
  Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

  ```bash
  git add Timers/Timers/Views/AdHocSheet.swift
  git commit -m "Add AdHocSheet with countdown picker and sound selection"
  ```

---

## Task 13: ProfileEditorSheet

**Files:**
- Create: `Timers/Timers/Views/ProfileEditorSheet.swift`

- [ ] **Step 1: Create `ProfileEditorSheet.swift`**

  ```swift
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
  ```

- [ ] **Step 2: Build**

  ```bash
  xcodebuild -scheme Timers -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -3
  ```
  Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

  ```bash
  git add Timers/Timers/Views/ProfileEditorSheet.swift
  git commit -m "Add ProfileEditorSheet for creating and editing timer profiles"
  ```

---

## Task 14: SettingsView

**Files:**
- Create: `Timers/Timers/Views/SettingsView.swift`

- [ ] **Step 1: Create `SettingsView.swift`**

  ```swift
  // Timers/Views/SettingsView.swift
  import SwiftUI
  import UserNotifications

  struct SettingsView: View {
      @AppStorage("defaultSoundName") private var defaultSoundName: String = "default"
      @AppStorage("layoutMode") private var layoutModeRaw: String = LayoutMode.activeOnTop.rawValue
      @AppStorage("hasShownNotificationNudge") private var hasShownNotificationNudge: Bool = false

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
  ```

- [ ] **Step 2: Build**

  ```bash
  xcodebuild -scheme Timers -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -3
  ```
  Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

  ```bash
  git add Timers/Timers/Views/SettingsView.swift
  git commit -m "Add SettingsView with default sound, layout mode, and notification permission status"
  ```

---

## Task 15: Widget Extension — Live Activity Views

**Files:**
- Modify: `Timers/TimersWidgetExtension/TimersLiveActivity.swift`

The widget extension generates a stub `TimersLiveActivity.swift` when you added "Include Live Activity". Replace it entirely.

- [ ] **Step 1: Replace `TimersLiveActivity.swift`**

  ```swift
  // TimersWidgetExtension/TimersLiveActivity.swift
  import ActivityKit
  import WidgetKit
  import SwiftUI

  @main
  struct TimersWidgetBundle: WidgetBundle {
      var body: some Widget {
          TimersLiveActivity()
      }
  }

  struct TimersLiveActivity: Widget {
      var body: some WidgetConfiguration {
          ActivityConfiguration(for: TimerAttributes.self) { context in
              // Lock screen / StandBy view
              LockScreenView(context: context)
          } dynamicIsland: { context in
              DynamicIsland {
                  // Expanded (long-press)
                  DynamicIslandExpandedRegion(.leading) {
                      Label(context.attributes.profileName, systemImage: "timer")
                          .font(.caption)
                          .lineLimit(1)
                  }
                  DynamicIslandExpandedRegion(.trailing) {
                      CountdownLabel(context: context)
                  }
                  DynamicIslandExpandedRegion(.bottom) {
                      ProgressView(
                          value: progressValue(context: context),
                          total: 1.0
                      )
                      .tint(.green)
                  }
              } compactLeading: {
                  Image(systemName: "timer")
                      .foregroundStyle(.green)
              } compactTrailing: {
                  CountdownLabel(context: context)
              } minimal: {
                  CountdownLabel(context: context)
              }
          }
      }

      private func progressValue(context: ActivityViewContext<TimerAttributes>) -> Double {
          guard !context.state.isFinished else { return 1.0 }
          let elapsed = context.state.endDate.timeIntervalSinceNow
          let remaining = max(0, elapsed)
          return 1.0 - (remaining / context.attributes.totalDuration)
      }
  }

  // MARK: - Subviews

  private struct CountdownLabel: View {
      let context: ActivityViewContext<TimerAttributes>

      var body: some View {
          if context.state.isFinished {
              Text("Done")
                  .font(.caption.bold())
                  .foregroundStyle(.green)
          } else {
              Text(context.state.endDate, style: .timer)
                  .font(.system(.caption, design: .monospaced).bold())
                  .monospacedDigit()
                  .foregroundStyle(.primary)
          }
      }
  }

  private struct LockScreenView: View {
      let context: ActivityViewContext<TimerAttributes>

      var body: some View {
          HStack {
              Label(context.attributes.profileName, systemImage: "timer")
                  .font(.headline)
              Spacer()
              if context.state.isFinished {
                  Text("Done")
                      .foregroundStyle(.green)
                      .font(.headline.bold())
              } else {
                  Text(context.state.endDate, style: .timer)
                      .font(.system(.headline, design: .monospaced).bold())
                      .monospacedDigit()
              }
          }
          .padding()
      }
  }
  ```

- [ ] **Step 2: Build the widget extension**

  ```bash
  xcodebuild -scheme TimersWidgetExtension -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -3
  ```
  Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Build the full app**

  ```bash
  xcodebuild -scheme Timers -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -3
  ```
  Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

  ```bash
  git add Timers/TimersWidgetExtension/TimersLiveActivity.swift
  git commit -m "Implement Live Activity views: lock screen, Dynamic Island compact and expanded"
  ```

---

## Task 16: UI Tests

**Files:**
- Modify: `Timers/TimersUITests/TimersUITests.swift`

- [ ] **Step 1: Replace the boilerplate in `TimersUITests.swift`**

  ```swift
  // TimersUITests/TimersUITests.swift
  import XCTest

  final class TimersUITests: XCTestCase {

      var app: XCUIApplication!

      override func setUpWithError() throws {
          continueAfterFailure = false
          app = XCUIApplication()
          app.launchArguments = ["--uitesting"]   // lets the app skip onboarding/permission prompts
          app.launch()
      }

      // MARK: - Ad Hoc Timer

      func test_adHocTimer_startAndAppearInActiveSection() throws {
          // Tap the timer (⏱) button in the nav bar
          app.navigationBars["Timers"].buttons["timer"].tap()

          // The ad hoc sheet should appear
          XCTAssertTrue(app.navigationBars["Quick Timer"].waitForExistence(timeout: 2))

          // Tap Start
          app.navigationBars["Quick Timer"].buttons["Start"].tap()

          // Sheet should dismiss and an instance row appear
          XCTAssertFalse(app.navigationBars["Quick Timer"].exists)

          // An instance row should appear (the default 1-min countdown)
          // The row appears in the "Active" section header or list
          XCTAssertTrue(app.staticTexts["Active"].waitForExistence(timeout: 2))
      }

      // MARK: - Saved Timer From Group

      func test_savedTimer_tapProfileStartsInstance() throws {
          // First, create a profile via the + button
          app.navigationBars["Timers"].buttons["plus"].tap()
          XCTAssertTrue(app.navigationBars["New Timer"].waitForExistence(timeout: 2))

          let nameField = app.textFields["Timer name"]
          nameField.tap()
          nameField.typeText("Earl Grey")

          app.navigationBars["New Timer"].buttons["Save"].tap()
          XCTAssertFalse(app.navigationBars["New Timer"].exists)

          // Tap the saved profile row to start it
          app.staticTexts["Earl Grey"].tap()

          // An "Active" section should appear
          XCTAssertTrue(app.staticTexts["Active"].waitForExistence(timeout: 2))
      }
  }
  ```

- [ ] **Step 2: Add `--uitesting` launch argument handling to `TimersApp.swift`**

  In `TimersApp`, inside `WindowGroup`, wrap the `.task` that requests notification permission:

  ```swift
  .task {
      guard !CommandLine.arguments.contains("--uitesting") else { return }
      await requestNotificationPermission()
  }
  ```

- [ ] **Step 3: Run UI tests**

  ```bash
  xcodebuild test -scheme Timers -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:TimersUITests 2>&1 | grep -E "Test Suite|PASS|FAIL|error:"
  ```
  Expected: both UI tests pass.

- [ ] **Step 4: Commit**

  ```bash
  git add Timers/TimersUITests/TimersUITests.swift Timers/Timers/TimersApp.swift
  git commit -m "Add UI tests for ad hoc timer flow and saved timer from group"
  ```

---

## Task 17: Final Build, Full Test Run, and Push

- [ ] **Step 1: Run the full test suite**

  ```bash
  xcodebuild test -scheme Timers -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 \
    | grep -E "Test Suite 'All|passed|failed"
  ```
  Expected: all tests pass, 0 failures.

- [ ] **Step 2: Run preflight checks**

  ```bash
  bd preflight
  ```

- [ ] **Step 3: Push**

  ```bash
  git pull --rebase
  bd dolt push
  git push
  git status
  ```
  Expected: `Your branch is up to date with 'origin/main'.`
