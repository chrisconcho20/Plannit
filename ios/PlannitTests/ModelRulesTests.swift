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

    // MARK: proposals

    private func proposal(finalized: String? = nil, myVote: String? = nil,
                          slotStart: Date? = nil) -> PProposal {
        let members = [member("me", "You"), member("maya", "Maya"), member("theo", "Theo")]
        let slot = PSlot(id: "s1", day: "SAT", date: 15, time: "2:00 – 4:00 PM", free: 3,
                         best: true, availableIds: ["me", "theo"], startsAt: slotStart)
        return PProposal(id: "p1", title: "Five-a-side", group: group(members: members),
                         constraint: "Sat · afternoon · 2h",
                         status: finalized == nil ? "voting" : "found",
                         slots: [slot], myVoteSlotId: myVote,
                         finalizedSlotId: finalized, createdBy: "me")
    }

    func testBadgeNudgesOnlyForRealReasons() {
        XCTAssertEqual(proposal().nudge(for: "me"), .needsYourVote)
        XCTAssertNil(proposal(myVote: "s1").nudge(for: "me"), "you've answered it")
        XCTAssertNil(proposal(finalized: "s1", myVote: "s1", slotStart: at(3, 14)).nudge(for: "me"),
                     "locked in, but not today")
        XCTAssertEqual(proposal(finalized: "s1", myVote: "s1", slotStart: at(0, 23)).nudge(for: "me"),
                       .happeningToday)
    }

    func testOnlyTheOrganiserOrOwnerCanFinalize() {
        let p = proposal()                       // createdBy "me", group owner "me"
        XCTAssertTrue(p.canFinalize("me"))
        XCTAssertFalse(p.canFinalize("maya"), "a plain member can vote, not lock in")
        XCTAssertTrue(p.canFinalize(nil), "demo mode")
    }

    func testSlotShowsThePeopleActuallyFree() {
        let p = proposal()
        XCTAssertEqual(p.people(for: p.slots[0]), ["You", "Theo"],
                       "mapped from availableIds, not the first N members")
    }

    func testSlotFallsBackWhenAvailabilityIsUnknown() {
        let members = [member("1", "Maya"), member("2", "Theo"), member("3", "Ada")]
        let slot = PSlot(day: "SUN", date: 16, time: "1:00 PM", free: 2)   // no availableIds
        let p = PProposal(id: "p", title: "x", group: group(members: members),
                          constraint: "", status: "voting", slots: [slot])
        XCTAssertEqual(p.people(for: slot), ["Maya", "Theo"], "first N as a stand-in")
    }

    func testFinalizedSlotLookup() {
        let p = proposal(finalized: "s1", slotStart: at(2, 14))
        XCTAssertTrue(p.isFinalized)
        XCTAssertEqual(p.finalizedSlot?.id, "s1")
        XCTAssertNil(proposal().finalizedSlot)
    }

    func testTotalIsTheGroupSize() {
        XCTAssertEqual(proposal().total, 3)
    }

}
