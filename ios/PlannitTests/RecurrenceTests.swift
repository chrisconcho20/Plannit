import EventKit
import XCTest
@testable import Plannit

// The repeat-rule engine. Dates are built from local components and the
// assertions are about local components too — hour-of-day, day-of-month,
// weekday — so they hold whatever timezone the test host runs in. That's also
// exactly the property the daylight-saving tests care about: the promise isn't
// "168 hours later", it's "same time next week".

final class RecurrenceTests: XCTestCase {
    private let cal = Calendar.current

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }
    private func hour(_ d: Date) -> Int { cal.component(.hour, from: d) }
    private func day(_ d: Date) -> Int { cal.component(.day, from: d) }
    private func month(_ d: Date) -> Int { cal.component(.month, from: d) }
    private func weekday(_ d: Date) -> Int { cal.component(.weekday, from: d) }
    private func daysBetween(_ a: Date, _ b: Date) -> Int {
        cal.dateComponents([.day], from: cal.startOfDay(for: a), to: cal.startOfDay(for: b)).day ?? -1
    }

    // MARK: - RRULE round trip

    func testEveryRuleRoundTripsThroughItsRRule() {
        for rule in RepeatRule.allCases {
            XCTAssertEqual(Recurrence.rule(from: Recurrence.rrule(for: rule)), rule, rule.rawValue)
        }
        XCTAssertNil(Recurrence.rrule(for: .never), "a one-off event has no rule")
        XCTAssertEqual(Recurrence.rrule(for: .daily), "FREQ=DAILY")
        XCTAssertEqual(Recurrence.rrule(for: .weekly), "FREQ=WEEKLY")
        XCTAssertEqual(Recurrence.rrule(for: .fortnightly), "FREQ=WEEKLY;INTERVAL=2")
        XCTAssertEqual(Recurrence.rrule(for: .monthly), "FREQ=MONTHLY")
    }

    func testRuleFromSurvivesAnythingTheColumnMightHold() {
        XCTAssertEqual(Recurrence.rule(from: nil), .never)
        XCTAssertEqual(Recurrence.rule(from: ""), .never)
        XCTAssertEqual(Recurrence.rule(from: "   "), .never)
        XCTAssertEqual(Recurrence.rule(from: "GARBAGE"), .never)
        XCTAssertEqual(Recurrence.rule(from: "=;="), .never)
        XCTAssertEqual(Recurrence.rule(from: "FREQ=YEARLY"), .never, "valid RFC, not one of ours")
        XCTAssertEqual(Recurrence.rule(from: "FREQ=WEEKLY;INTERVAL=3"), .never)
        XCTAssertEqual(Recurrence.rule(from: "FREQ=DAILY;INTERVAL=xyz"), .never)
    }

    func testRuleFromIgnoresCaseSpacingAndOrder() {
        XCTAssertEqual(Recurrence.rule(from: "freq=weekly;interval=2"), .fortnightly)
        XCTAssertEqual(Recurrence.rule(from: "  RRULE:FREQ=DAILY  "), .daily, "property name stripped")
        XCTAssertEqual(Recurrence.rule(from: "INTERVAL=1;FREQ=MONTHLY"), .monthly, "order-independent")
        XCTAssertEqual(Recurrence.rule(from: "FREQ=WEEKLY;INTERVAL=1"), .weekly, "the RFC default, spelled out")
    }

    func testABoundedRuleIsRefusedRatherThanTruncated() {
        // We can't show "every week, five times" in the picker, and keeping the
        // FREQ while dropping the limit would repeat the event forever.
        XCTAssertEqual(Recurrence.rule(from: "FREQ=WEEKLY;COUNT=5"), .never)
        XCTAssertEqual(Recurrence.rule(from: "FREQ=WEEKLY;UNTIL=20261231T000000Z"), .never)
        XCTAssertEqual(Recurrence.rule(from: "FREQ=WEEKLY;BYDAY=MO,WE"), .never)
    }

    func testLabels() {
        XCTAssertEqual(RepeatRule.allCases.map(\.label),
                       ["Never", "Every day", "Every week", "Every 2 weeks", "Every month"])
        XCTAssertEqual(RepeatRule.fortnightly.id, "fortnightly", "the id is the stored raw value")
    }

    // MARK: - Daylight saving

    func testWeeklyKeepsItsLocalTimeWhenTheClocksGoBack() {
        // 2pm Sundays across 1 November 2026, when the US clocks go back.
        let start = date(2026, 10, 18, 14)
        let dates = Recurrence.occurrences(start: start, rule: .weekly,
                                           in: start...date(2026, 12, 13, 23, 59))
        XCTAssertEqual(dates.count, 9)
        for d in dates {
            XCTAssertEqual(hour(d), 14, "2pm stays 2pm: \(d)")
            XCTAssertEqual(weekday(d), weekday(start), "and the same weekday")
        }
        XCTAssertEqual(dates.last, date(2026, 12, 13, 14))
    }

    func testWeeklyKeepsItsLocalTimeWhenTheClocksGoForward() {
        let start = date(2026, 2, 22, 14)   // spans 8 March 2026
        let dates = Recurrence.occurrences(start: start, rule: .weekly,
                                           in: start...date(2026, 4, 5, 23, 59))
        XCTAssertEqual(dates.count, 7)
        XCTAssertTrue(dates.allSatisfy { hour($0) == 14 })
        XCTAssertEqual(dates.last, date(2026, 4, 5, 14))
    }

    func testDailyRunsEveryCalendarDayThroughTheChange() {
        let start = date(2026, 10, 30, 14)
        let dates = Recurrence.occurrences(start: start, rule: .daily,
                                           in: start...date(2026, 11, 3, 14))
        XCTAssertEqual(dates, [start, date(2026, 10, 31, 14), date(2026, 11, 1, 14),
                               date(2026, 11, 2, 14), date(2026, 11, 3, 14)])
        XCTAssertTrue(dates.allSatisfy { hour($0) == 14 })
    }

    // MARK: - Fortnightly

    func testFortnightlyLandsOnFourteenDayMultiplesOnly() {
        let start = date(2026, 10, 18, 14)
        let dates = Recurrence.occurrences(start: start, rule: .fortnightly,
                                           in: start...date(2026, 12, 31, 23, 59))
        XCTAssertEqual(dates, [start,
                               date(2026, 11, 1, 14),   // the clocks change on this one
                               date(2026, 11, 15, 14),
                               date(2026, 11, 29, 14),
                               date(2026, 12, 13, 14),
                               date(2026, 12, 27, 14)])
        for (a, b) in zip(dates, dates.dropFirst()) {
            XCTAssertEqual(daysBetween(a, b), 14, "no odd week ever appears")
        }
    }

    // MARK: - Monthly

    func testMonthlyOnTheThirtyFirstSkipsTheShortMonths() {
        let start = date(2026, 1, 31, 9)
        let dates = Recurrence.occurrences(start: start, rule: .monthly,
                                           in: start...date(2026, 12, 31, 23, 59))
        XCTAssertEqual(dates.map { month($0) }, [1, 3, 5, 7, 8, 10, 12],
                       "February, April, June, September and November have no 31st")
        XCTAssertTrue(dates.allSatisfy { day($0) == 31 },
                      "never nudged to the 1st, never clamped to the 30th")
        XCTAssertTrue(dates.allSatisfy { hour($0) == 9 })
    }

    func testMonthlyOnTheThirtiethSkipsOnlyFebruary() {
        let dates = Recurrence.occurrences(start: date(2026, 1, 30, 9), rule: .monthly,
                                           in: date(2026, 1, 1)...date(2026, 12, 31, 23, 59))
        XCTAssertEqual(dates.count, 11)
        XCTAssertFalse(dates.contains { month($0) == 2 })
    }

    func testMonthlyOnTheFifteenthIsUneventful() {
        let start = date(2026, 1, 15, 18, 30)
        let dates = Recurrence.occurrences(start: start, rule: .monthly,
                                           in: start...date(2026, 12, 31, 23, 59))
        XCTAssertEqual(dates.map { month($0) }, Array(1...12))
        XCTAssertTrue(dates.allSatisfy { day($0) == 15 })
        // Spans both 2026 clock changes, so the time of day has to survive them.
        XCTAssertTrue(dates.allSatisfy { hour($0) == 18 })
    }

    // MARK: - The range

    func testTheRangeClipsBothEndsInclusively() {
        let start = date(2026, 3, 2, 9)
        let first = date(2026, 3, 16, 9), last = date(2026, 4, 6, 9)
        let dates = Recurrence.occurrences(start: start, rule: .weekly, in: first...last)
        XCTAssertEqual(dates, [first, date(2026, 3, 23, 9), date(2026, 3, 30, 9), last],
                       "an occurrence exactly on either bound is in")
    }

    func testAnEventStartingAfterTheRangeHasNoOccurrences() {
        let range = date(2026, 3, 1)...date(2026, 4, 1)
        XCTAssertTrue(Recurrence.occurrences(start: date(2026, 5, 1, 9), rule: .daily,
                                             in: range).isEmpty)
        XCTAssertTrue(Recurrence.occurrences(start: date(2026, 5, 1, 9), rule: .never,
                                             in: range).isEmpty)
    }

    func testAnEventThatStartedYearsAgoStillFillsTheWindowAsked() {
        // The cap must not be spent walking from 2015 to the month on screen.
        let start = date(2015, 6, 3, 7)
        let dates = Recurrence.occurrences(start: start, rule: .weekly,
                                           in: date(2026, 8, 1)...date(2026, 8, 31, 23, 59))
        XCTAssertEqual(dates.count, 4, "August 2026 has four of that weekday")
        XCTAssertTrue(dates.allSatisfy { weekday($0) == weekday(start) })
        XCTAssertTrue(dates.allSatisfy { hour($0) == 7 })
    }

    // MARK: - The cap

    func testTheLimitTerminatesAWideRange() {
        let start = date(2020, 1, 1, 8)
        let range = start...date(2030, 1, 1, 8)   // a decade of daily occurrences

        let capped = Recurrence.occurrences(start: start, rule: .daily, in: range)
        XCTAssertEqual(capped.count, 400, "the default cap")
        XCTAssertEqual(capped.first, start)

        let three = Recurrence.occurrences(start: start, rule: .daily, in: range, limit: 3)
        XCTAssertEqual(three, [start, date(2020, 1, 2, 8), date(2020, 1, 3, 8)])

        XCTAssertTrue(Recurrence.occurrences(start: start, rule: .daily, in: range, limit: 0).isEmpty)
    }

    func testTheCapIsMeasuredInOccurrencesNotSteps() {
        // Monthly on the 31st has to reach 100 real occurrences even though
        // five months in twelve produce none.
        let start = date(2020, 1, 31, 9)
        let dates = Recurrence.occurrences(start: start, rule: .monthly,
                                           in: start...date(2060, 1, 1), limit: 100)
        XCTAssertEqual(dates.count, 100)
        XCTAssertTrue(dates.allSatisfy { day($0) == 31 })
    }

    // MARK: - Never

    func testNeverIsJustTheEventItself() {
        let start = date(2026, 8, 15, 14)
        XCTAssertEqual(Recurrence.occurrences(start: start, rule: .never,
                                              in: date(2026, 8, 1)...date(2026, 8, 31, 23, 59)),
                       [start])
        XCTAssertEqual(Recurrence.occurrences(start: start, rule: .never, in: start...start),
                       [start], "inclusive bounds")
        XCTAssertTrue(Recurrence.occurrences(start: start, rule: .never,
                                             in: date(2026, 9, 1)...date(2026, 9, 30)).isEmpty,
                      "range after the event")
        XCTAssertTrue(Recurrence.occurrences(start: start, rule: .never,
                                             in: date(2026, 7, 1)...date(2026, 7, 31)).isEmpty,
                      "range before the event")
    }

    // MARK: - EventKit

    func testEKRuleMirrorsTheSameShape() {
        XCTAssertNil(Recurrence.ekRule(for: .never))
        XCTAssertEqual(Recurrence.ekRule(for: .daily)?.frequency, EKRecurrenceFrequency.daily)
        XCTAssertEqual(Recurrence.ekRule(for: .daily)?.interval, 1)
        XCTAssertEqual(Recurrence.ekRule(for: .weekly)?.frequency, EKRecurrenceFrequency.weekly)
        XCTAssertEqual(Recurrence.ekRule(for: .fortnightly)?.frequency, EKRecurrenceFrequency.weekly)
        XCTAssertEqual(Recurrence.ekRule(for: .fortnightly)?.interval, 2)
        XCTAssertEqual(Recurrence.ekRule(for: .monthly)?.frequency, EKRecurrenceFrequency.monthly)
        XCTAssertNil(Recurrence.ekRule(for: .weekly)?.recurrenceEnd, "runs until the event is deleted")
    }
}
