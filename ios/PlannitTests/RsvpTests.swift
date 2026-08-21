import XCTest
@testable import Plannit

// Going / not going is the whole participation model for a group plan
// (decision D-12, revised). Two rules carry it, and both are easy to get
// subtly wrong:
//
//   1. an invitation is NOT on your calendar until you say yes;
//   2. saying no takes it back off.
//
// These run against the demo path (the test host has no Supabase config),
// which shares its local bookkeeping with the optimistic live path — so the
// state machine is covered even though the round trip isn't.

@MainActor
final class RsvpTests: XCTestCase {
    private var model: AppModel!

    private let members = [PMember(id: "me", name: "You"),
                           PMember(id: "maya", name: "Maya"),
                           PMember(id: "theo", name: "Theo")]

    override func setUp() async throws {
        model = AppModel()
        model.userId = "me"
        model.groups = [PGroup(id: "g1", name: "Soccer", hue: .teal,
                               members: members, note: "", ownerId: "maya")]
        model.events = [invitation, mine]
    }

    /// Maya's plan, offered to the group, unanswered by you.
    private var invitation: PEvent {
        PEvent(id: "e1", start: Date().addingTimeInterval(86_400), title: "Five-a-side",
               time: "2:00 PM", ownerId: "maya", rsvps: ["maya": true],
               sharedGroupIds: ["g1"])
    }

    /// Something you put in your own calendar — no RSVP anywhere near it.
    private var mine: PEvent {
        PEvent(id: "e2", start: Date().addingTimeInterval(3600), title: "Dentist",
               time: "9:15 AM", ownerId: "me")
    }

    private func live(_ id: String) -> PEvent { model.events.first { $0.id == id }! }

    // MARK: the two rules

    func testAnInvitationIsNotOnYourCalendarUntilYouSayYes() {
        XCTAssertFalse(live("e1").isOnCalendar(for: "me"))
        XCTAssertTrue(live("e1").needsAnswer(from: "me"))
        XCTAssertEqual(model.plansBadge, 1)
    }

    func testSayingYesPutsItOnYourCalendar() async {
        await model.rsvp(to: live("e1"), going: true)

        XCTAssertEqual(live("e1").myRsvp("me"), true)
        XCTAssertTrue(live("e1").isOnCalendar(for: "me"))
        XCTAssertFalse(live("e1").needsAnswer(from: "me"), "answered — stop nagging")
        XCTAssertNil(model.plansBadge)
        XCTAssertEqual(live("e1").goingCount, 2, "Maya's, plus yours")
    }

    func testSayingNoTakesItBackOff() async {
        await model.rsvp(to: live("e1"), going: true)
        await model.rsvp(to: live("e1"), going: false)

        XCTAssertEqual(live("e1").myRsvp("me"), false)
        XCTAssertFalse(live("e1").isOnCalendar(for: "me"),
                       "removing it from your calendar is what declining means")
        XCTAssertEqual(live("e1").goingCount, 1, "only Maya")
        XCTAssertNil(model.plansBadge, "you answered — no is an answer")
    }

    func testChangingYourMindDoesNotDoubleCount() async {
        await model.rsvp(to: live("e1"), going: true)
        await model.rsvp(to: live("e1"), going: true)
        XCTAssertEqual(live("e1").goingCount, 2)
    }

    // MARK: whose plan it is

    func testTheOrganiserIsGoingByDefault() {
        let theirs = live("e1")
        XCTAssertEqual(theirs.myRsvp("maya"), true, "picking the time said so")
        XCTAssertTrue(theirs.isOnCalendar(for: "maya"))
        XCTAssertFalse(theirs.needsAnswer(from: "maya"), "you don't invite yourself")
    }

    func testYourOwnEventsAreNotInvitations() {
        XCTAssertFalse(live("e2").isGroupEvent)
        XCTAssertTrue(live("e2").isOnCalendar(for: "me"))
        XCTAssertFalse(live("e2").needsAnswer(from: "me"))
    }

    // MARK: what the Plans tab shows

    func testPlansSplitsIntoUnansweredAndGoing() async {
        XCTAssertEqual(model.invitations.map(\.id), ["e1"])
        XCTAssertTrue(model.upcomingPlans.isEmpty)

        await model.rsvp(to: live("e1"), going: true)

        XCTAssertTrue(model.invitations.isEmpty)
        XCTAssertEqual(model.upcomingPlans.map(\.id), ["e1"])
    }

    func testPastPlansDropOffTheList() async {
        model.events = [PEvent(id: "e3", start: Date().addingTimeInterval(-172_800),
                               end: Date().addingTimeInterval(-165_600),
                               title: "Last week's game", time: "2:00 PM",
                               ownerId: "maya", rsvps: ["maya": true, "me": true],
                               sharedGroupIds: ["g1"], sharedUserIds: ["me"])]
        XCTAssertTrue(model.upcomingPlans.isEmpty, "you went; it's over")
    }

    func testRepeatingPlansKeepTheirAnswers() {
        let weekly = PEvent(id: "e4", start: Date().addingTimeInterval(3600),
                            end: Date().addingTimeInterval(7200), title: "Five-a-side",
                            time: "2:00 PM", ownerId: "maya",
                            recurrence: .weekly, rsvps: ["maya": true, "me": true],
                            sharedGroupIds: ["g1"], sharedUserIds: ["me"])
        let range = Date()...Date().addingTimeInterval(30 * 86_400)
        let occurrences = weekly.occurrences(in: range)

        XCTAssertGreaterThan(occurrences.count, 1)
        XCTAssertTrue(occurrences.allSatisfy { $0.isOnCalendar(for: "me") },
                      "an expanded occurrence must carry the answer, or every week "
                      + "after the first vanishes off your calendar")
    }
}
