import XCTest
@testable import Plannit

// The small pieces added in the polish pass: duration round-tripping when you
// edit an event, and the per-group colour store.

@MainActor
final class PolishTests: XCTestCase {

    // MARK: start and end

    func testAnEventKeepsTheTimesYouChose() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let end = start.addingTimeInterval(90 * 60)
        let span = AppModel.span(start: start, end: end, allDay: false)
        XCTAssertEqual(span.0, start)
        XCTAssertEqual(span.1, end, "90 minutes is a perfectly good length")
    }

    func testAnEndBeforeItsStartIsFloored() {
        // The picker won't let you choose one, but dragging the start past the
        // end can produce one. It must never reach the database — the events
        // table has a check constraint that would reject it.
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let span = AppModel.span(start: start, end: start.addingTimeInterval(-3600),
                                 allDay: false)
        XCTAssertGreaterThan(span.1, span.0)
    }

    func testAllDayCoversTheWholeDay() {
        let cal = Calendar.current
        let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
        let span = AppModel.span(start: noon, end: noon.addingTimeInterval(3600), allDay: true)
        XCTAssertEqual(span.0, cal.startOfDay(for: noon))
        XCTAssertEqual(span.1, cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: noon)))
    }

    // MARK: group colour

    func testAPickedHueWinsOverTheDerivedOne() {
        let id = "group-\(UUID().uuidString)"
        let derived = GroupHue.forName("Soccer")
        let other = GroupHue.allCases.first { $0 != derived }!

        XCTAssertEqual(GroupHue.forGroup(id: id, name: "Soccer"), derived, "no choice yet")
        GroupHue.pick(other, for: id)
        XCTAssertEqual(GroupHue.forGroup(id: id, name: "Soccer"), other)
        XCTAssertEqual(GroupHue.picked(for: id), other)
    }

    func testHuesAreRememberedPerGroup() {
        let a = "group-a-\(UUID().uuidString)", b = "group-b-\(UUID().uuidString)"
        GroupHue.pick(.teal, for: a)
        GroupHue.pick(.rose, for: b)
        XCTAssertEqual(GroupHue.picked(for: a), .teal)
        XCTAssertEqual(GroupHue.picked(for: b), .rose)
        XCTAssertNil(GroupHue.picked(for: "group-never-picked"))
    }

    func testDerivedHueIsStableForAName() {
        XCTAssertEqual(GroupHue.forName("Soccer"), GroupHue.forName("Soccer"))
    }

    // MARK: stored session

    func testStoredSessionKnowsWhenItIsStale() {
        let fresh = StoredSession(accessToken: "a", refreshToken: "r", userId: "u",
                                  email: nil, expiresAt: Date().addingTimeInterval(3600))
        let expiring = StoredSession(accessToken: "a", refreshToken: "r", userId: "u",
                                     email: nil, expiresAt: Date().addingTimeInterval(30))
        let expired = StoredSession(accessToken: "a", refreshToken: "r", userId: "u",
                                    email: nil, expiresAt: Date().addingTimeInterval(-10))
        XCTAssertTrue(fresh.isFresh)
        XCTAssertFalse(expiring.isFresh, "inside the 60s margin — refresh before using")
        XCTAssertFalse(expired.isFresh)
    }

    /// Exercises whichever store is available: the Keychain on a signed build,
    /// the UserDefaults fallback on an unsigned simulator (CI, Appetize).
    func testSessionStorageRoundTrip() {
        let key = "test-\(UUID().uuidString)"
        let session = StoredSession(accessToken: "token", refreshToken: "refresh",
                                    userId: "uid", email: "a@b.c",
                                    expiresAt: Date(timeIntervalSince1970: 1_800_000_000))
        Keychain.save(session, for: key)
        defer { Keychain.delete(key) }

        let loaded = Keychain.load(StoredSession.self, for: key)
        XCTAssertEqual(loaded?.accessToken, "token")
        XCTAssertEqual(loaded?.refreshToken, "refresh")
        XCTAssertEqual(loaded?.userId, "uid")
        XCTAssertEqual(loaded?.email, "a@b.c")

        Keychain.delete(key)
        XCTAssertNil(Keychain.load(StoredSession.self, for: key), "sign-out really forgets")
    }
}
