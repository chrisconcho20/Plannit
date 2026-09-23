import XCTest
@testable import Plannit

// Sharing one of your own calendar's events with a group.
//
// The rule that makes this safe to build at all: the phone stays the source of
// truth. Plannit holds a copy so the group can see it, tied to the phone's event
// by `external_cal_id` — so moving the dinner on your phone moves it for
// everyone, and sharing twice doesn't produce two events.

@MainActor
final class SharedDeviceEventTests: XCTestCase {
    private var model: AppModel!
    private let start = Date(timeIntervalSince1970: 1_786_838_400)

    override func setUp() async throws {
        model = AppModel()
        model.userId = "me"
    }

    private func device(id: String = "ext-1", title: String = "Dinner with Ada",
                        start: Date? = nil, hours: Double = 2,
                        location: String? = "Bermondsey",
                        allDay: Bool = false) -> DeviceEvent {
        let from = start ?? self.start
        return DeviceEvent(id: "local-\(id)", externalId: id, title: title,
                           start: from, end: from.addingTimeInterval(hours * 3600),
                           location: location, isAllDay: allDay)
    }

    private func copy(of d: DeviceEvent) -> PEvent {
        PEvent(id: "row-1", start: d.start, end: d.end, title: d.title, time: "",
               location: d.location, source: .device, externalCalId: d.externalId,
               isAllDay: d.isAllDay, ownerId: "me")
    }

    // MARK: sharing once

    func testSharingCopiesTheEventAndKeepsTheLink() async {
        let d = device()
        let shared = await model.shareDeviceEvent(d)

        XCTAssertEqual(shared?.title, "Dinner with Ada")
        XCTAssertEqual(shared?.externalCalId, "ext-1",
                       "without the external id the copy is an orphan — nothing can "
                       + "keep it in step with the phone")
        XCTAssertTrue(shared?.isFromDeviceCalendar == true)
    }

    func testSharingTwiceReusesTheSameRow() async {
        let d = device()
        let first = await model.shareDeviceEvent(d)
        let second = await model.shareDeviceEvent(d)

        XCTAssertEqual(first?.id, second?.id)
        XCTAssertEqual(model.events.filter { $0.externalCalId == "ext-1" }.count, 1,
                       "the DB has unique(owner_id, external_cal_id) — don't race it")
    }

    func testTheCopyIsFoundBackFromTheDeviceEvent() async {
        let d = device()
        XCTAssertNil(model.sharedCopy(of: d), "nothing shared yet")
        _ = await model.shareDeviceEvent(d)
        XCTAssertNotNil(model.sharedCopy(of: d))
    }

    func testAnEventWithNoStableIdHasNoCopy() {
        let anonymous = DeviceEvent(id: "local-x", externalId: nil, title: "Mystery",
                                    start: start, end: start.addingTimeInterval(3600),
                                    location: nil, isAllDay: false)
        XCTAssertNil(model.sharedCopy(of: anonymous))
    }

    // MARK: staying in step with the phone

    func testAnUnchangedEventIsNotRewritten() {
        let d = device()
        XCTAssertFalse(AppModel.differs(copy(of: d), from: d),
                       "an idle sync must not write to the database")
    }

    func testMovingItOnThePhoneCountsAsAChange() {
        let d = device()
        let moved = device(start: start.addingTimeInterval(2 * 3600))
        XCTAssertTrue(AppModel.differs(copy(of: d), from: moved),
                      "you moved dinner to 9pm; the group is still looking at 7pm")
    }

    func testRenamingOrRelocatingCountsAsAChange() {
        let d = device()
        XCTAssertTrue(AppModel.differs(copy(of: d), from: device(title: "Dinner with Sam")))
        XCTAssertTrue(AppModel.differs(copy(of: d), from: device(location: "Peckham")))
        XCTAssertTrue(AppModel.differs(copy(of: d), from: device(location: nil)))
    }

    func testBecomingAllDayCountsAsAChange() {
        XCTAssertTrue(AppModel.differs(copy(of: device()), from: device(allDay: true)))
    }

    func testSubSecondDriftIsNotAChange() {
        // The two sides round differently; rewriting on that would mean a write
        // on every single sync, forever.
        let d = device()
        var jittered = copy(of: d)
        jittered = PEvent(id: jittered.id, start: d.start.addingTimeInterval(0.4),
                          end: d.end.addingTimeInterval(-0.4), title: d.title, time: "",
                          location: d.location, source: .device,
                          externalCalId: d.externalId, isAllDay: false, ownerId: "me")
        XCTAssertFalse(AppModel.differs(jittered, from: d))
    }
}

// The calendar's dots and its day list disagreed about this rule: the list
// dropped the phone's copy of a shared event, the dots counted it, so sharing
// an event left two marks on its day — one in the group's colour, one in the
// device coral. Reported from a device on 2026-09-23.
@MainActor
final class DeviceEventDedupeTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_786_838_400)

    private func device(_ id: String, externalId: String?, at offset: TimeInterval = 0) -> DeviceEvent {
        DeviceEvent(id: id, externalId: externalId, title: "Dinner",
                    start: start.addingTimeInterval(offset),
                    end: start.addingTimeInterval(offset + 3600),
                    location: nil, isAllDay: false)
    }

    private func copy(of externalId: String?) -> PEvent {
        PEvent(id: "row-1", start: start, end: start.addingTimeInterval(3600),
               title: "Dinner", time: "7:00 PM", source: .device,
               externalCalId: externalId, ownerId: "me")
    }

    func testAnEventPlannitAlreadyHoldsIsCountedOnce() {
        let result = AppModel.deviceEventsWithoutCopies(
            [device("d1", externalId: "ext-1")], copies: [copy(of: "ext-1")])
        XCTAssertTrue(result.isEmpty, "the Plannit copy represents it, so the device row is dropped")
    }

    func testUnsharedEventsSurvive() {
        let result = AppModel.deviceEventsWithoutCopies(
            [device("d1", externalId: "ext-1"), device("d2", externalId: "ext-2", at: 7200)],
            copies: [copy(of: "ext-1")])
        XCTAssertEqual(result.map(\.id), ["d2"])
    }

    /// An event with no stable id can't be matched to a copy, and dropping it
    /// would hide it from the calendar entirely.
    func testAnEventWithoutAnExternalIdIsKept() {
        let result = AppModel.deviceEventsWithoutCopies(
            [device("d1", externalId: nil)], copies: [copy(of: "ext-1")])
        XCTAssertEqual(result.map(\.id), ["d1"])
    }

    func testTheResultIsInTimeOrder() {
        let result = AppModel.deviceEventsWithoutCopies(
            [device("late", externalId: "b", at: 7200), device("early", externalId: "a")],
            copies: [])
        XCTAssertEqual(result.map(\.id), ["early", "late"])
    }
}
