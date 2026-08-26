import XCTest
@testable import Plannit

// Moving a plan, and what it does to the people who already answered.
//
// The rule is a judgement call, so it gets pinned down here rather than left to
// whoever reads the sheet next: a different time on the same day keeps
// everyone's answers, a different day asks them again. The failure this
// prevents is the stale yes — being recorded as going to a Sunday morning you
// were never asked about.

@MainActor
final class RescheduleTests: XCTestCase {
    private let cal = Calendar.current
    private var saturday2pm: Date {
        cal.date(from: DateComponents(year: 2026, month: 9, day: 5, hour: 14))!
    }

    private func plan() -> PEvent {
        PEvent(id: "e1", start: saturday2pm, end: saturday2pm.addingTimeInterval(7200),
               title: "Five-a-side", time: "2:00 PM", ownerId: "me",
               rsvps: ["me": true, "maya": true, "theo": false],
               sharedGroupIds: ["g1"], sharedUserIds: ["maya"])
    }

    // MARK: which moves re-open the question

    func testSameDayKeepsAnswers() {
        let later = saturday2pm.addingTimeInterval(3600)
        XCTAssertFalse(AppModel.resetsAnswers(movingFrom: saturday2pm, to: later),
                       "an hour later is a detail, not a new commitment")
    }

    func testADifferentDayAsksAgain() {
        let sunday = cal.date(byAdding: .day, value: 1, to: saturday2pm)!
        XCTAssertTrue(AppModel.resetsAnswers(movingFrom: saturday2pm, to: sunday))
    }

    func testCrossingMidnightCountsAsADifferentDay() {
        // 11pm Saturday → 1am Sunday is two hours and a different night out.
        let elevenPM = cal.date(bySettingHour: 23, minute: 0, second: 0, of: saturday2pm)!
        let oneAM = elevenPM.addingTimeInterval(2 * 3600)
        XCTAssertTrue(AppModel.resetsAnswers(movingFrom: elevenPM, to: oneAM))
    }

    // MARK: what the move does to the state

    func testAKeptMoveLeavesEveryoneWhereTheyWere() {
        let later = saturday2pm.addingTimeInterval(3600)
        let moved = AppModel.moved(plan(), to: later, end: later.addingTimeInterval(7200),
                                   clearingAnswers: false, owner: "me")

        XCTAssertEqual(moved.start, later)
        XCTAssertEqual(moved.rsvps["maya"], true, "still going, at the new time")
        XCTAssertEqual(moved.rsvps["theo"], false, "still not going")
        XCTAssertEqual(moved.sharedUserIds, ["maya"], "it stays on Maya's calendar")
    }

    func testAResetMoveTakesItOffEveryoneElsesCalendar() {
        let sunday = cal.date(byAdding: .day, value: 1, to: saturday2pm)!
        let moved = AppModel.moved(plan(), to: sunday, end: sunday.addingTimeInterval(7200),
                                   clearingAnswers: true, owner: "me")

        XCTAssertNil(moved.rsvps["maya"], "asked again, not assumed")
        XCTAssertNil(moved.rsvps["theo"])
        XCTAssertEqual(moved.rsvps["me"], true, "you don't re-invite yourself")
        XCTAssertFalse(moved.isOnCalendar(for: "maya"),
                       "the personal share is the visibility — leaving it would show "
                       + "Maya a time she never agreed to")
        XCTAssertTrue(moved.needsAnswer(from: "maya"))
        XCTAssertTrue(moved.isOnCalendar(for: "me"))
    }

    func testTheGroupItWasOfferedToDoesNotChange() {
        let sunday = cal.date(byAdding: .day, value: 1, to: saturday2pm)!
        let moved = AppModel.moved(plan(), to: sunday, end: sunday.addingTimeInterval(7200),
                                   clearingAnswers: true, owner: "me")
        XCTAssertEqual(moved.sharedGroupIds, ["g1"],
                       "it's the same plan for the same group — only the time moved")
    }

    // MARK: who may move it

    func testOnlyTheOrganiserCanMoveIt() async {
        let model = AppModel()
        model.userId = "maya"          // Maya is going, but it isn't her plan
        model.events = [plan()]

        let ok = await model.reschedule(plan(), to: saturday2pm.addingTimeInterval(3600),
                                        end: saturday2pm.addingTimeInterval(10800))
        XCTAssertFalse(ok)
        XCTAssertEqual(model.events.first?.start, saturday2pm, "nothing moved")
    }

    func testTheOrganiserMovingItUpdatesTheLocalCopy() async {
        let model = AppModel()
        model.userId = "me"
        model.events = [plan()]
        let sunday = cal.date(byAdding: .day, value: 1, to: saturday2pm)!

        let ok = await model.reschedule(plan(), to: sunday, end: sunday.addingTimeInterval(7200))
        XCTAssertTrue(ok)
        let moved = try? XCTUnwrap(model.events.first)
        XCTAssertEqual(moved?.start, sunday)
        XCTAssertNil(moved?.rsvps["maya"], "a new day re-opens the question")
    }
}
