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
