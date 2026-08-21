import XCTest
@testable import Plannit

// The constraint maths behind the wedge. Everything here is deterministic:
// dates are built from local components so the assertions hold whatever
// timezone the simulator runs in.

final class SlotFinderTests: XCTestCase {
    private let cal = Calendar.current

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }
    private func epochMs(_ d: Date) -> Int64 { Int64(d.timeIntervalSince1970 * 1000) }

    // MARK: constraints

    func testConstraintsMapsTheUIOntoTheContract() {
        let now = date(2026, 8, 14, 15, 47)
        let c = SlotFinder.constraints(days: [6, 0], timeOfDay: "Afternoon",
                                       duration: "2h", months: 6, now: now)

        XCTAssertEqual(c.allowedWeekdays, [0, 6], "sorted, 0=Sun…6=Sat")
        XCTAssertEqual(c.dayStartMinutes, 12 * 60)
        XCTAssertEqual(c.dayEndMinutes, 17 * 60)
        XCTAssertEqual(c.durationMinutes, 120)
        XCTAssertEqual(c.stepMinutes, 30)
        XCTAssertEqual(c.timezone, TimeZone.current.identifier)
        XCTAssertNil(c.quorum, "the scheduler decides — everyone first, majority as fallback")
    }

    func testWindowStartsOnTheNextWholeHour() {
        // Candidates step every 30 minutes from windowStart, so a ragged start
        // would offer people 3:47pm.
        let c = SlotFinder.constraints(days: [1], timeOfDay: "Morning", duration: "1h",
                                       months: 1, now: date(2026, 8, 14, 15, 47))
        XCTAssertEqual(c.windowStart, epochMs(date(2026, 8, 14, 16, 0)))
    }

    func testWindowLengthFollowsThePreference() {
        let now = date(2026, 8, 14, 9, 0)
        let start = date(2026, 8, 14, 10, 0)
        for months in [1, 3, 6, 12] {
            let c = SlotFinder.constraints(days: [3], timeOfDay: "Evening", duration: "1h",
                                           months: months, now: now)
            let expected = cal.date(byAdding: .month, value: months, to: start)!
            XCTAssertEqual(c.windowEnd, epochMs(expected), "\(months) months")
        }
    }

    func testTimeOfDayWindows() {
        func window(_ label: String) -> (Int, Int) {
            let c = SlotFinder.constraints(days: [0], timeOfDay: label, duration: "1h",
                                           months: 1, now: date(2026, 8, 14, 9, 0))
            return (c.dayStartMinutes, c.dayEndMinutes)
        }
        XCTAssertEqual(window("Morning").0, 8 * 60)
        XCTAssertEqual(window("Morning").1, 12 * 60)
        XCTAssertEqual(window("Evening").0, 17 * 60)
        XCTAssertEqual(window("Evening").1, 22 * 60)
        // An unknown label must not crash or produce an empty window.
        XCTAssertEqual(window("Whenever").0, 12 * 60, "falls back to afternoon")
    }

    func testDurationParsing() {
        XCTAssertEqual(SlotFinder.minutes(from: "1h"), 60)
        XCTAssertEqual(SlotFinder.minutes(from: "4h"), 240)
        XCTAssertEqual(SlotFinder.minutes(from: "nonsense"), 120, "defaults to 2h")
    }

    // MARK: slot mapping

    func testSlotFormatsATimeRange() {
        let start = date(2026, 8, 15, 14), end = date(2026, 8, 15, 16)
        let slot = SlotFinder.slot(from: FoundSlotDTO(start: epochMs(start), end: epochMs(end),
                                                      score: 6, availableUserIds: ["a", "b"]),
                                   best: true)
        XCTAssertEqual(slot.time, "2:00 – 4:00 PM", "the meridiem isn't repeated")
        XCTAssertEqual(slot.date, 15)
        XCTAssertEqual(slot.day, "SAT")
        XCTAssertEqual(slot.free, 6)
        XCTAssertTrue(slot.best)
        XCTAssertEqual(slot.availableIds, ["a", "b"], "carried through for real avatars")
    }

    func testSlotCrossingNoonKeepsBothMeridiems() {
        let start = date(2026, 8, 16, 11), end = date(2026, 8, 16, 13)
        let slot = SlotFinder.slot(from: FoundSlotDTO(start: epochMs(start), end: epochMs(end),
                                                      score: 5, availableUserIds: []))
        XCTAssertEqual(slot.time, "11:00 AM – 1:00 PM")
        XCTAssertFalse(slot.best)
    }

    // MARK: the search window preference

    func testSearchWindowFallsBackWhenUnsetOrJunk() {
        let defaults = UserDefaults.standard
        let original = defaults.object(forKey: SearchWindow.key)
        defer {
            if let original { defaults.set(original, forKey: SearchWindow.key) }
            else { defaults.removeObject(forKey: SearchWindow.key) }
        }

        defaults.removeObject(forKey: SearchWindow.key)
        XCTAssertEqual(SearchWindow.months, SearchWindow.defaultMonths)

        defaults.set(7, forKey: SearchWindow.key)   // not one of the options
        XCTAssertEqual(SearchWindow.months, SearchWindow.defaultMonths)

        defaults.set(3, forKey: SearchWindow.key)
        XCTAssertEqual(SearchWindow.months, 3)
    }

    func testSearchWindowCopy() {
        XCTAssertEqual(SearchWindow.label(6), "6 mo")
        XCTAssertEqual(SearchWindow.label(12), "1 year")
        XCTAssertEqual(SearchWindow.phrase(1), "the next 1 month")
        XCTAssertEqual(SearchWindow.phrase(6), "the next 6 months")
        XCTAssertEqual(SearchWindow.phrase(12), "the next year")
    }

    func testTimeOfDayDescribesAStoredWindow() {
        XCTAssertEqual(TimeOfDay.describing(from: 12 * 60, to: 17 * 60), "afternoon")
        XCTAssertEqual(TimeOfDay.describing(from: 8 * 60, to: 12 * 60), "morning")
        XCTAssertEqual(TimeOfDay.describing(from: 9 * 60 + 30, to: 11 * 60), "9:30–11:00",
                       "a hand-rolled window still reads back")
    }

    // MARK: grouping by date
    //
    // The organiser picks a DATE. Offering five slots on one afternoon is the
    // same date wearing five hats, so the list is thinned to two times a day.

    private func found(_ start: Date, hours: Int = 2, score: Int = 6) -> PSlot {
        SlotFinder.slot(from: FoundSlotDTO(
            start: epochMs(start),
            end: epochMs(start.addingTimeInterval(Double(hours) * 3600)),
            score: score, availableUserIds: []))
    }

    func testAtMostTwoTimesPerDate() {
        let sat = date(2026, 8, 15, 12)
        let slots = (0..<5).map { found(sat.addingTimeInterval(Double($0) * 3600)) }
        let grouped = SlotFinder.byDate(slots)

        XCTAssertEqual(grouped.count, 1, "one date")
        XCTAssertEqual(grouped[0].slots.count, 2, "two times, not five")
        XCTAssertEqual(grouped[0].slots.map(\.time), slots.prefix(2).map(\.time),
                       "the scheduler already ranked them — keep the best two")
    }

    func testDatesStayInRankedOrder() {
        let sun = date(2026, 8, 16, 14)
        let sat = date(2026, 8, 15, 14)
        // Sunday scored better, so the scheduler put it first: date order must
        // not quietly re-sort it.
        let grouped = SlotFinder.byDate([found(sun, score: 6), found(sat, score: 5)])
        XCTAssertEqual(grouped.map { self.cal.component(.day, from: $0.date) }, [16, 15])
    }

    func testTheListOfDatesIsCapped() {
        let slots = (0..<10).map { found(date(2026, 8, 15, 14).addingTimeInterval(Double($0) * 86_400)) }
        XCTAssertEqual(SlotFinder.byDate(slots).count, SlotFinder.maxDates)
    }

    func testASlotWithoutAnInstantIsSkipped() {
        let orphan = PSlot(day: "SAT", date: 15, time: "2:00 PM", free: 3)   // no startsAt
        XCTAssertTrue(SlotFinder.byDate([orphan]).isEmpty)
    }
}
