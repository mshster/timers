# Timers App — Design Spec

**Date:** 2026-04-25
**Platform:** iOS 17+, SwiftUI
**Purpose:** Personal timer app replacing the Clock app's Timers tab, with named/grouped presets, simultaneous instances, Live Activities, and no auto-save of ad hoc timers.

---

## Data Model

### `TimerProfile` (SwiftData, persisted)
| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | |
| `name` | `String` | |
| `duration` | `TimeInterval` | seconds |
| `group` | `String?` | nil = ungrouped |
| `soundName` | `String?` | nil = use global default |
| `sortOrder` | `Int` | user-defined ordering |

### `TimerInstance` (in-memory, ephemeral)
| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | |
| `profileId` | `UUID?` | nil for ad hoc |
| `displayName` | `String` | copied from profile name; for ad hoc, derived from duration (e.g. "5:00") |
| `duration` | `TimeInterval` | |
| `startTime` | `Date` | wall clock |
| `soundName` | `String` | resolved at start time |
| `activity` | `Activity<TimerAttributes>?` | Live Activity reference |
| `state` | `InstanceState` | `.running`, `.finished` |

Instances are written to a JSON sidecar file in the app's support directory when the app backgrounds, and reconstructed on foreground.

### `TimerGroup`
Not a separate entity. Groups are the distinct non-nil `group` values across all `TimerProfile` records, derived at query time. Groups appear and disappear automatically as profiles are created and deleted.

### `AppSettings`
Stored in `@AppStorage` / `UserDefaults`:
- `defaultSoundName: String`
- `layoutMode: LayoutMode` (`.activeOnTop` | `.activeInPlace`)

---

## Architecture

**Stack:** SwiftUI + SwiftData + `TimerEngine` service + ActivityKit Widget Extension

### `TimerEngine` (`@Observable` singleton, environment-injected)

Central service owning all running instances. Views observe and dispatch; they contain no timer logic.

**Responsibilities:**

- **Instance lifecycle**
  - `start(profile:)` → creates `TimerInstance`, appends to `instances`
  - `startAdHoc(duration:sound:)` → same, `profileId = nil`
  - `cancel(instance:)` → removes instance, cancels notification, ends Live Activity
  - `dismiss(instance:)` → clears a finished instance from the finished set

- **Notification scheduling**
  - On `start`: registers `UNLocalNotificationRequest` with `UNTimeIntervalNotificationTrigger`
  - Notification payload carries instance ID for completion handling
  - On completion: `UNUserNotificationCenterDelegate` callback moves instance to `finished` set (drives in-app indicator), plays sound

- **Live Activities**
  - On `start`: calls `Activity<TimerAttributes>.request(...)` — caught silently if unavailable
  - On cancel: `activity.end(dismissalPolicy: .immediate)`
  - On finish: `activity.update(ContentState(isFinished: true))`, then `end(dismissalPolicy: .after(now + 4s))`
  - On foreground reconstruction: reconciles with `Activity.activities` to avoid re-requesting already-live activities

- **Background survival**
  - On `scenePhase → .background`: serialises all active instances to JSON sidecar
  - On `scenePhase → .active`: reads sidecar, recomputes remaining time from `Date() - startTime`
  - Instances with `remainingSeconds ≤ 0` are immediately moved to `finished`

- **Tick**
  - Single `Timer.publish(every: 1, on: .main, in: .common)` drives countdown UI for all instances — no per-instance timer

### `TimerListLayout` (protocol)

```swift
protocol TimerListLayout {
    func sections(instances: [TimerInstance], groups: [String],
                  profiles: [TimerProfile]) -> [TimerSection]
}
```

Two implementations:
- `ActiveOnTopLayout` — active instances in a leading "Active" section; profiles in group sections below
- `ActiveInPlaceLayout` — profiles in group sections; active instances rendered inline within their group row

`AppSettings.layoutMode` selects the implementation. Switching layout is a one-property change.

### Widget Extension

Separate Xcode target sharing `TimerAttributes` via a shared Swift package or source group.

`TimerAttributes: ActivityAttributes`
- Static: `profileName: String`, `totalDuration: TimeInterval`
- `ContentState`: `remainingSeconds: TimeInterval`, `isFinished: Bool`

Views provided:
- **Compact** (Dynamic Island leading/trailing): countdown digits
- **Expanded** (Dynamic Island long-press): name + progress arc + countdown
- **Lock screen / StandBy**: large countdown, name, finished state

---

## UI Structure

### Main List (root)
- Navigation bar: ⚙️ (Settings), title "Timers", ⏱ (ad hoc), + (new profile)
- Body: `List` assembled by the active `TimerListLayout`
  - Active instances show name, countdown, finished indicator (until dismissed)
  - Group sections are expandable; profile rows show name, duration, ▶ tap target
  - Ungrouped profiles in a plain section below groups
- **Tap** a profile row → `TimerEngine.start(profile:)`
- **Long-press** a profile row → context menu: Edit, Duplicate, Delete

### Ad Hoc Sheet
- Standard `UIDatePicker` in `.countDownTimer` mode (hour/minute/second dials)
- Sound picker row (defaults to global preference)
- Start button → `TimerEngine.startAdHoc(duration:sound:)`
- No name field; intentionally ephemeral

### Profile Editor Sheet
- Name field
- Duration picker (same dial style as ad hoc)
- Group field: free-text with autocomplete from existing group names
- Sound picker: built-in notification sounds via `UNNotificationSound` + "Use default" option (nil)
- Used for both create and edit modes

### Settings
- Default sound picker
- Layout mode toggle (A/B)
- Notification permission status + prompt if denied (shown once; no repeated nagging)

### Timer Detail *(v2 stretch)*
Tapping an active instance could push a detail view — natural location for pause, extend, or notes in a future version. Not in scope for v1.

---

## Completion Behaviour

When a timer instance finishes:
1. **Sound**: plays the instance's resolved sound
2. **Banner notification**: `UNUserNotificationCenter` delivers the scheduled notification
3. **In-app indicator**: instance moves to `finished` state; card glows / badges until user dismisses it
4. **Live Activity**: updates to finished state for ~4 seconds, then ends

If the user has denied notification permission, in-foreground completion still plays sound and shows the in-app indicator; background completion is best-effort (Live Activity still fires on lock screen).

---

## Error Handling

- **Live Activities unavailable**: caught silently; timer runs normally without lock screen / Dynamic Island presence
- **Notification permission denied**: one-time nudge in Settings; no repeated alerts
- **Background reconstruction with expired instance**: `remainingSeconds ≤ 0` → immediately mark finished, skip countdown
- **SwiftData errors**: unrecoverable → generic alert; recoverable save conflicts → silent single retry

---

## Testing

- `TimerEngine` unit-tested with an injected mock clock (`() -> Date`) and a mock `NotificationScheduler` protocol — no real `UNUserNotificationCenter` required
- UI tests cover: starting an ad hoc timer, starting a saved timer from a group
- Live Activities verified manually on device (simulator support limited)
- `TimerListLayout` implementations unit-tested independently with fixture data
