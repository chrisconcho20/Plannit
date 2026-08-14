import XCTest
@testable import Plannit

// Busy-block merging. This is the input the whole wedge runs on: get it wrong
// and the scheduler confidently offers a time someone can't make.

final class AvailabilityTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_786_838_400)   // fixed instant
    private func at(_ hours: Double) -> Date { base.addingTimeInterval(hours * 3600) }
    private func interval(_ from: Double, _ to: Double) -> BusyInterval {
        BusyInterval(start: at(from), end: at(to))
    }

    func testOverlappingMeetingsBecomeOneBlock() {
        let merged = Availability.merge([interval(14, 15), interval(14.5, 16)])
        XCTAssertEqual(merged, [interval(14, 16)])
    }

    func testBackToBackMeetingsBecomeOneBlock() {
        // 2–3 then 3–4 is a solid two hours with no gap to schedule into.
        XCTAssertEqual(Availability.merge([interval(14, 15), interval(15, 16)]),
                       [interval(14, 16)])
    }

    func testAGapIsPreserved() {
        let merged = Availability.merge([interval(9, 10), interval(14, 15)])
        XCTAssertEqual(merged, [interval(9, 10), interval(14, 15)])
    }

    func testAnEventInsideAnotherIsSwallowed() {
        // An all-hands with a 1:1 inside it is still just the all-hands.
        XCTAssertEqual(Availability.merge([interval(9, 17), interval(11, 12)]),
                       [interval(9, 17)])
    }

    func testOutOfOrderInputStillMerges() {
        let merged = Availability.merge([interval(16, 17), interval(9, 10), interval(9.5, 11)])
        XCTAssertEqual(merged, [interval(9, 11), interval(16, 17)])
    }

    func testZeroLengthAndInvertedIntervalsAreDropped() {
        XCTAssertEqual(Availability.merge([interval(10, 10)]), [])
        XCTAssertEqual(Availability.merge([interval(12, 11)]), [])
    }

    func testEmptyInput() {
        XCTAssertEqual(Availability.merge([]), [])
    }

    func testClipTrimsToTheHorizon() {
        // A week-long trip only counts inside the window we're scheduling in.
        let clipped = Availability.clip([interval(-10, 40)], from: at(0), to: at(24))
        XCTAssertEqual(clipped, [interval(0, 24)])
    }

    func testClipDropsWhatIsEntirelyOutside() {
        XCTAssertEqual(Availability.clip([interval(-10, -5)], from: at(0), to: at(24)), [])
        XCTAssertEqual(Availability.clip([interval(30, 40)], from: at(0), to: at(24)), [])
    }

    func testPrepareClipsThenMerges() {
        // Yesterday's meeting, one that straddles "now", and two that overlap.
        let prepared = Availability.prepare(
            [interval(-5, -4), interval(-1, 2), interval(1, 3), interval(20, 30)],
            from: at(0), to: at(24))
        XCTAssertEqual(prepared, [interval(0, 3), interval(20, 24)])
    }

    func testALargeCalendarCollapsesToTheSameCoverage() {
        // 500 overlapping half-hour meetings across a day = one block.
        let many = (0..<500).map { interval(Double($0) * 0.25, Double($0) * 0.25 + 0.5) }
        let merged = Availability.merge(many)
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged.first?.start, at(0))
        XCTAssertEqual(merged.first?.end, at(Double(499) * 0.25 + 0.5))
    }
}
