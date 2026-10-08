import XCTest
@testable import Plannit

// An event is on every day it touches. The calendar used to place everything
// on its start day only, so a Friday-to-Saturday event had no dot on Saturday
// and wasn't listed when Saturday was tapped.
final class DaySpanTests: XCTestCase {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }

    private func date(_ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        cal.date(from: DateComponents(year: 2026, month: m, day: d, hour: h))!
    }

    func testTwoDayEventIsOnBothDays() {
        let start = date(10, 9, 18), end = date(10, 10, 14)
        XCTAssertEqual(DaySpan.days(start: start, end: end, calendar: cal),
                       [cal.startOfDay(for: start), cal.startOfDay(for: end)])
        XCTAssertTrue(DaySpan.covers(date(10, 10), start: start, end: end, calendar: cal))
        XCTAssertFalse(DaySpan.covers(date(10, 11), start: start, end: end, calendar: cal))
    }

    func testEndingAtMidnightStaysOnOneDay() {
        let start = date(10, 9, 0), end = date(10, 10, 0)   // an all-day event
        XCTAssertEqual(DaySpan.days(start: start, end: end, calendar: cal).count, 1)
        XCTAssertFalse(DaySpan.covers(date(10, 10), start: start, end: end, calendar: cal))
    }

    func testNoEndOrZeroLengthIsTheStartDay() {
        let start = date(10, 9)
        XCTAssertEqual(DaySpan.days(start: start, end: nil, calendar: cal).count, 1)
        XCTAssertEqual(DaySpan.days(start: start, end: start, calendar: cal).count, 1)
    }

    func testEventRunningIntoARangeOverlapsIt() {
        let range = date(10, 10, 0)...date(10, 11, 0)
        XCTAssertTrue(DaySpan.overlaps(range, start: date(10, 9, 18), end: date(10, 10, 14)))
        XCTAssertFalse(DaySpan.overlaps(range, start: date(10, 9, 18), end: date(10, 10, 0)),
                       "ending exactly as the range starts is not inside it")
        XCTAssertFalse(DaySpan.overlaps(range, start: date(10, 11, 1), end: date(10, 11, 2)))
    }
}
