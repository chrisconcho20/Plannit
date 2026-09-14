import XCTest
@testable import Plannit

// The date finder's personal rules: the smallest turnout worth offering, and the
// hours someone is never free. Calendars here are pinned to a named time zone so
// the assertions don't depend on where the simulator thinks it is.

final class PlanPreferencesTests: XCTestCase {

    // MARK: - Minimum attendance

    func testTheFloorNeverExceedsTheGroupOrDropsBelowOne() {
        XCTAssertEqual(MinimumAttendance.one.floor(groupSize: 6), 1)
        XCTAssertEqual(MinimumAttendance.two.floor(groupSize: 6), 2)
        XCTAssertEqual(MinimumAttendance.five.floor(groupSize: 6), 5)
        XCTAssertEqual(MinimumAttendance.ten.floor(groupSize: 6), 6, "ten of six is everyone")
        XCTAssertEqual(MinimumAttendance.all.floor(groupSize: 6), 6)
        XCTAssertEqual(MinimumAttendance.two.floor(groupSize: 0), 1, "an empty group still asks for someone")
    }

    func testHalfRoundsUp() {
        XCTAssertEqual(MinimumAttendance.half.floor(groupSize: 6), 3)
        XCTAssertEqual(MinimumAttendance.half.floor(groupSize: 5), 3, "half of five people is three, not two")
        XCTAssertEqual(MinimumAttendance.half.floor(groupSize: 1), 1)
    }

    func testAllIsSentAsEveryoneTheServerCounts() {
        XCTAssertEqual(MinimumAttendance.all.quorum(groupSize: 4), MinimumAttendance.everyone,
                       "a member who joined since the group loaded still has to be free")
        XCTAssertEqual(MinimumAttendance.half.quorum(groupSize: 4), 2)
    }

    func testTheDefaultIsEveryone() {
        XCTAssertEqual(MinimumAttendance.defaultValue, .all)
    }

    func testPhrasing() {
        XCTAssertEqual(MinimumAttendance.all.phrase(groupSize: 6), "all 6")
        XCTAssertEqual(MinimumAttendance.half.phrase(groupSize: 6), "at least 3 of 6")
        XCTAssertEqual(MinimumAttendance.ten.phrase(groupSize: 4), "all 4")
    }

    func testTheSettingReachesTheRequest() {
        let c = SlotFinder.constraints(days: [6], timeOfDay: "Afternoon", duration: "2h",
                                       months: 3, quorum: 2)
        XCTAssertEqual(c.quorum, 2)
    }

    // MARK: - Hours you're never free

    private var newYork: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        return cal
    }

    private func local(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        newYork.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    func testOffAddsNothing() {
        var rule = NeverFreeHours(enabled: false, earliestMinutes: 9 * 60, latestMinutes: 22 * 60)
        XCTAssertTrue(rule.blocks(from: local(2026, 9, 14), to: local(2026, 9, 21), calendar: newYork).isEmpty)
        rule.enabled = true
        rule.earliestMinutes = 0
        rule.latestMinutes = NeverFreeHours.dayMinutes
        XCTAssertFalse(rule.isActive, "midnight to midnight with no days blocked rules nothing out")
    }

    func testAnOrdinaryDayIsBusyBeforeAndAfter() {
        let rule = NeverFreeHours(enabled: true, earliestMinutes: 9 * 60, latestMinutes: 22 * 60)
        let blocks = rule.blocks(from: local(2026, 9, 15), to: local(2026, 9, 16), calendar: newYork)

        XCTAssertEqual(blocks, [
            BusyInterval(start: local(2026, 9, 15, 0), end: local(2026, 9, 15, 9)),
            BusyInterval(start: local(2026, 9, 15, 22), end: local(2026, 9, 16, 0)),
        ])
    }

    func testANeverFreeDayIsBusyAllDay() {
        // 2026-09-20 is a Sunday.
        let rule = NeverFreeHours(enabled: true, earliestMinutes: 0,
                                  latestMinutes: NeverFreeHours.dayMinutes, blockedWeekdays: [0])
        let blocks = rule.blocks(from: local(2026, 9, 19), to: local(2026, 9, 21), calendar: newYork)
        XCTAssertEqual(blocks, [BusyInterval(start: local(2026, 9, 20), end: local(2026, 9, 21))])
    }

    func testNightsJoinUpOnceMerged() {
        let rule = NeverFreeHours(enabled: true, earliestMinutes: 9 * 60, latestMinutes: 22 * 60)
        let from = local(2026, 9, 15), to = local(2026, 9, 18)
        let merged = Availability.prepare(rule.blocks(from: from, to: to, calendar: newYork),
                                          from: from, to: to)
        XCTAssertEqual(merged.count, 4, "one block per night plus the two ends, not two per day")
        XCTAssertEqual(merged[1], BusyInterval(start: local(2026, 9, 15, 22), end: local(2026, 9, 16, 9)))
    }

    func testTheClockTimeHoldsAcrossADaylightSavingChange() {
        // Clocks go forward at 2am on 2026-03-08 in New York.
        let rule = NeverFreeHours(enabled: true, earliestMinutes: 9 * 60, latestMinutes: NeverFreeHours.dayMinutes)
        let blocks = rule.blocks(from: local(2026, 3, 8), to: local(2026, 3, 9), calendar: newYork)

        let end = try? XCTUnwrap(blocks.first?.end)
        XCTAssertEqual(end.map { newYork.component(.hour, from: $0) }, 9,
                       "still 9am on the wall clock, even though the morning was an hour shorter")
    }

    func testTheRuleSurvivesARoundTrip() throws {
        let rule = NeverFreeHours(enabled: true, earliestMinutes: 510, latestMinutes: 1350,
                                  blockedWeekdays: [0, 6])
        let data = try JSONEncoder().encode(rule)
        XCTAssertEqual(try JSONDecoder().decode(NeverFreeHours.self, from: data), rule)
    }

    func testTheSummarySaysWhatItDoes() {
        XCTAssertEqual(NeverFreeHours().summary, "Off")
        let evenings = NeverFreeHours(enabled: true, earliestMinutes: 0, latestMinutes: 21 * 60)
        XCTAssertTrue(evenings.summary.hasPrefix("Not after"), evenings.summary)
        let midnight = NeverFreeHours.label(NeverFreeHours.dayMinutes)
        XCTAssertEqual(midnight, "Midnight")
    }
}
