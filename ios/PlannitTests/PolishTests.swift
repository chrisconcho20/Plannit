import XCTest
@testable import Plannit

// The small pieces added in the polish pass: duration round-tripping when you
// edit an event, and the per-group colour store.

@MainActor
final class PolishTests: XCTestCase {

    // MARK: duration chips

    func testExactDurationsRoundTrip() {
        for label in ["30m", "1h", "2h", "3h"] {
            XCTAssertEqual(NewEventSheet.label(forMinutes: NewEventSheet.minutes(label)), label)
        }
    }

    func testOffDurationsPickTheNearestChip() {
        XCTAssertEqual(NewEventSheet.label(forMinutes: 20), "30m")
        XCTAssertEqual(NewEventSheet.label(forMinutes: 100), "2h")
        XCTAssertEqual(NewEventSheet.label(forMinutes: 500), "3h", "clamps to the longest")
    }

    func testTiesAreDeterministic() {
        // 90 is equidistant from 1h and 2h — it must resolve the same way every
        // time, or an unedited event would change duration on reopen.
        XCTAssertEqual(NewEventSheet.label(forMinutes: 90), "1h")
        XCTAssertEqual(NewEventSheet.label(forMinutes: 90), NewEventSheet.label(forMinutes: 90))
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

    func testKeychainRoundTrip() {
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
