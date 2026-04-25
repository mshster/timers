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
}
