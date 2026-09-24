import XCTest
@testable import Plannit

// What the list under the calendar covers. The tab decides the span; the span
// is clamped to today, because the section is about what is still to come:
// looking at this month lists the rest of it, and a month already behind us
// has nothing upcoming in it at all.
final class CalendarListScopeTests: XCTestCase {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        c.firstWeekday = 1
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    private func scope(_ mode: CalendarScreen.Mode, selected: Date? = nil,
                       month: Date, now: Date) -> CalendarScreen.ListScope {
        CalendarScreen.listScope(mode: mode, selectedDate: selected, visibleMonth: month,
                                 now: now, calendar: cal)
    }

    func testThisMonthStartsFromTodayNotTheFirst() {
        let now = date(2026, 9, 24)
        guard case .range(let range) = scope(.month, month: now, now: now) else {
            return XCTFail("expected a range")
        }
        XCTAssertEqual(range.lowerBound, cal.startOfDay(for: now),
                       "the 1st to the 23rd have already happened")
        XCTAssertFalse(range.contains(date(2026, 9, 3)))
        XCTAssertTrue(range.contains(date(2026, 9, 30)))
    }

    func testAFutureMonthIsShownWhole() {
        let now = date(2026, 9, 24)
        guard case .range(let range) = scope(.month, month: date(2026, 10, 15), now: now) else {
            return XCTFail("expected a range")
        }
        XCTAssertTrue(range.contains(date(2026, 10, 1)), "no part of October has passed")
        XCTAssertTrue(range.contains(date(2026, 10, 31)))
    }

    func testAPastMonthHasNothingUpcoming() {
        XCTAssertEqual(scope(.month, month: date(2026, 8, 10), now: date(2026, 9, 24)), .empty)
    }

    func testTheCurrentWeekStartsFromToday() {
        let now = date(2026, 9, 24)          // a Thursday
        guard case .range(let range) = scope(.week, month: now, now: now) else {
            return XCTFail("expected a range")
        }
        XCTAssertEqual(range.lowerBound, cal.startOfDay(for: now))
        XCTAssertFalse(range.contains(date(2026, 9, 21)), "Monday has been and gone")
        XCTAssertTrue(range.contains(date(2026, 9, 26)))
    }

    func testAPastWeekHasNothingUpcoming() {
        XCTAssertEqual(scope(.week, selected: date(2026, 9, 10), month: date(2026, 9, 10),
                             now: date(2026, 9, 24)), .empty)
    }

    func testATappedDayIsShownWhicheverDayItIs() {
        let past = date(2026, 9, 3)
        XCTAssertEqual(scope(.month, selected: past, month: past, now: date(2026, 9, 24)), .day(past))
    }

    func testListRunsForwardWithoutABound() {
        let now = date(2026, 9, 24)
        XCTAssertEqual(scope(.list, month: now, now: now), .unbounded)
        XCTAssertEqual(scope(.list, selected: date(2026, 9, 3), month: now, now: now), .unbounded,
                       "List ignores a day tapped on another tab")
    }
}
