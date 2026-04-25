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
