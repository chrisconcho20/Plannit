import XCTest
@testable import Plannit

// The model rules that decide what the UI is allowed to show: who owns a thing,
// what's private, which day an event falls on, and why a plan is nagging you.
// Each of these has already been a bug once.

@MainActor   // NewEventSheet is a View, so its statics are main-actor isolated
final class ModelRulesTests: XCTestCase {
    private let cal = Calendar.current
    private func at(_ days: Int, _ hour: Int) -> Date {
        let day = cal.date(byAdding: .day, value: days, to: Date())!
        return cal.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
    }

    private func member(_ id: String, _ name: String) -> PMember { PMember(id: id, name: name) }

    private func group(owner: String = "me", members: [PMember] = []) -> PGroup {
        PGroup(id: "g1", name: "Soccer", hue: .teal, members: members, note: "", ownerId: owner)
    }

    // MARK: events

    func testEventFallsOnItsRealDayNotJustADayNumber() {
        // The calendar used to key off day-of-month, so a 15 Sept event lit up
        // 15 August. isOn compares whole dates.
        let event = PEvent(id: "e", start: at(30, 14), title: "Five-a-side", time: "2:00 PM")
        XCTAssertTrue(event.isOn(at(30, 9)), "same day, different hour")
        XCTAssertFalse(event.isOn(at(30 - 1, 14)))
        XCTAssertFalse(event.isOn(cal.date(byAdding: .month, value: 1, to: at(30, 14))!))
    }

    func testEventPrivacyAndOwnership() {
        var event = PEvent(id: "e", start: at(1, 12), title: "Dentist", time: "12:00 PM",
                           ownerId: "me")
        XCTAssertTrue(event.isPrivate)
        XCTAssertTrue(event.isOwned(by: "me"))
        XCTAssertFalse(event.isOwned(by: "someone-else"))

        event.sharedGroupIds = ["g1"]
        XCTAssertFalse(event.isPrivate)
    }

    func testDemoEventsAreAlwaysYours() {
        // No ownerId and no signed-in user = demo mode; sharing must stay usable.
        let event = PEvent(id: "e", start: at(1, 12), title: "Film night", time: "8:00 PM")
        XCTAssertTrue(event.isOwned(by: nil))
    }

    // MARK: groups

    func testGroupOwnershipDecidesDeleteVersusLeave() {
        let g = group(owner: "me")
        XCTAssertTrue(g.isOwned(by: "me"))
        XCTAssertFalse(g.isOwned(by: "maya"))
        XCTAssertTrue(g.isOwned(by: nil), "demo mode owns everything")
    }

    func testMemberNamesSurviveBlankProfiles() {
        let g = group(members: [member("1", "Maya Ellis"), member("2", "Member")])
        XCTAssertEqual(g.memberNames, ["Maya Ellis", "Member"])
        XCTAssertEqual(g.members.count, 2, "a nameless member still counts — '1 of 0 free' bug")
    }
}
