import XCTest
import SwiftUI
@testable import Plannit

// The month grid put its leading blanks and its days in two sibling ForEach
// views inside one LazyVGrid, so both numbered their cells from a shared
// identity space: the blanks claimed 0, 1, 2… and the days claimed 1, 2, 3….
// SwiftUI dropped the collisions, and every month opened with no 1st and its
// first week in the wrong columns. These tests hold the layout to the calendar.
final class MonthGridTests: XCTestCase {

    /// Sunday-first, matching the header row the grid draws.
    private var gregorian: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        c.firstWeekday = 1
        return c
    }

    private func cells(_ year: Int, _ month: Int) -> [MonthGrid.Cell] {
        MonthGrid.cells(year: year, month: month, calendar: gregorian)
    }

    func testEveryDayOfTheMonthIsPresentExactlyOnce() {
        for month in 1...12 {
            let days = cells(2026, month).compactMap(\.day)
            let expected = gregorian.range(
                of: .day, in: .month,
                for: gregorian.date(from: DateComponents(year: 2026, month: month, day: 1))!)!
            XCTAssertEqual(days, Array(expected),
                           "month \(month) should run 1…\(expected.count) with nothing missing")
        }
    }

    func testEveryCellIdIsUnique() {
        for month in 1...12 {
            let ids = cells(2026, month).map(\.id)
            XCTAssertEqual(ids.count, Set(ids).count,
                           "month \(month) has colliding ids, which is what lost the 1st")
        }
    }

    /// The column a day lands in has to be its real weekday, for every day of
    /// every month — including October 2026, which is where this was noticed.
    func testEachDaySitsUnderItsRealWeekday() {
        for year in [2026, 2027] {
            for month in 1...12 {
                for (index, cell) in cells(year, month).enumerated() {
                    guard let day = cell.day else {
                        XCTAssertTrue(index < 7, "blanks only ever precede the first week")
                        continue
                    }
                    let date = gregorian.date(from: DateComponents(year: year, month: month, day: day))!
                    let weekday = gregorian.component(.weekday, from: date)   // 1=Sun
                    XCTAssertEqual(index % 7, weekday - 1,
                                   "\(year)-\(month)-\(day) is in the wrong column")
                }
            }
        }
    }

    /// A month starting on a Sunday has no blanks at all — the case where the
    /// old code happened to look right.
    func testAMonthStartingOnSundayHasNoBlanks() {
        XCTAssertEqual(cells(2026, 11).first?.day, 1, "1 November 2026 is a Sunday")
        XCTAssertEqual(cells(2026, 10).prefix(4).compactMap(\.day).count, 0,
                       "1 October 2026 is a Thursday, so four blanks come first")
        XCTAssertEqual(cells(2026, 10)[4].day, 1)
    }
}
