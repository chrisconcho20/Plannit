import EventKit
import XCTest
@testable import Plannit

// The rules that decide what the scheduler is allowed to believe about you.
//
// Every assertion here is about the same failure: `find-slots` reads "no busy
// block" as "free". So a horizon that stops short of the search window, or a
// filter that drops a real commitment, doesn't make Plannit cautious — it makes
// it confidently wrong, and the wrongness lands as "everyone's free" on a date
// where they aren't.

final class CalendarHorizonTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_786_838_400)
    private let cal = Calendar.current

    private func months(_ n: Int, from date: Date) -> Date {
        cal.date(byAdding: .month, value: n, to: date)!
    }

    // MARK: the horizon covers the search window

    func testTheHorizonCoversTheWholeSearchWindow() {
        for months in SearchWindow.options {
            let horizon = Availability.horizon(months: months, from: now)
            XCTAssertGreaterThan(
                horizon, self.months(months, from: now),
                "a \(months)-month search past a \(months)-month horizon asks about "
                + "time we uploaded nothing for, and gets 'everyone's free'")
        }
    }

    func testTheHorizonKeepsSlackForTheGapBetweenSyncs() {
        // Someone syncs today and searches six months next week: still covered.
        let horizon = Availability.horizon(months: 6, from: now)
        let searchedNextWeek = months(6, from: cal.date(byAdding: .day, value: 7, to: now)!)
        XCTAssertGreaterThan(horizon, searchedNextWeek)
    }

    func testTheHorizonIsCappedAtTheLongestOfferedWindow() {
        // A junk preference must not turn into a ten-year EventKit predicate.
        let absurd = Availability.horizon(months: 600, from: now)
        XCTAssertLessThanOrEqual(absurd, months(13, from: now))
    }

    func testTheHorizonHasAFloor() {
        XCTAssertGreaterThan(Availability.horizon(months: 0, from: now), now)
        XCTAssertGreaterThan(Availability.horizon(months: -3, from: now), now)
    }

    // MARK: what counts as busy

    /// EKEvents need a store; an in-memory one is fine, nothing is saved.
    private let store = EKEventStore()
    private func event(_ start: Date, _ end: Date, allDay: Bool = false,
                       availability: EKEventAvailability = .busy,
                       status: EKEventStatus = .confirmed) -> EKEvent {
        let e = EKEvent(eventStore: store)
        e.startDate = start
        e.endDate = end
        e.isAllDay = allDay
        e.availability = availability
        // `status` is read-only on EKEvent; the cancelled case is covered by
        // the filter's own source order and exercised on device (test 02).
        return e
    }
    private func hours(_ n: Double, from date: Date) -> Date {
        date.addingTimeInterval(n * 3600)
    }

    func testAnOrdinaryMeetingIsBusy() {
        XCTAssertTrue(CalendarService.isBusy(event(now, hours(1, from: now))))
    }

    func testSomethingMarkedFreeIsNotBusy() {
        XCTAssertFalse(CalendarService.isBusy(
            event(now, hours(1, from: now), availability: .free)),
            "you told your own calendar this doesn't block you")
    }

    func testABirthdayDoesNotBlockTheDay() {
        let day = cal.startOfDay(for: now)
        let allDay = event(day, cal.date(byAdding: .day, value: 1, to: day)!, allDay: true)
        XCTAssertFalse(CalendarService.isBusy(allDay))
    }

    func testAMultiDayTripDoesBlock() {
        // Five all-day days called "Portugal" is exactly the week nobody should
        // be offered — and the old filter let it through as free.
        let day = cal.startOfDay(for: now)
        let trip = event(day, cal.date(byAdding: .day, value: 5, to: day)!, allDay: true)
        XCTAssertTrue(CalendarService.isBusy(trip))
    }

    func testAnAllDayEventEndingAtMidnightIsStillOneDay() {
        // All-day events end at 00:00 the *next* day. Comparing end dates
        // naively makes every birthday look like a two-day trip.
        let day = cal.startOfDay(for: now)
        let birthday = event(day, cal.date(byAdding: .day, value: 1, to: day)!, allDay: true)
        XCTAssertFalse(CalendarService.isBusy(birthday))
    }

    // MARK: occurrence identity

    func testEveryOccurrenceOfARepeatingEventGetsItsOwnId() {
        // EventKit hands every occurrence the same eventIdentifier. Used raw as
        // a SwiftUI id, a weekly standup renders as duplicate rows.
        let week1 = event(now, hours(1, from: now))
        let week2 = event(cal.date(byAdding: .day, value: 7, to: now)!,
                          hours(1, from: cal.date(byAdding: .day, value: 7, to: now)!))
        XCTAssertNotEqual(CalendarService.occurrenceId(for: week1),
                          CalendarService.occurrenceId(for: week2))
    }

    func testTheSameOccurrenceKeepsAStableId() {
        let e = event(now, hours(1, from: now))
        XCTAssertEqual(CalendarService.occurrenceId(for: e),
                       CalendarService.occurrenceId(for: e),
                       "re-reading the calendar must not reshuffle the list")
    }
}
