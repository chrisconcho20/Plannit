import XCTest
@testable import Plannit

// Two ways data leaves a person's phone and account: the Plannit calendar copy
// of their plans, and deleting the account outright.

@MainActor
final class AccountAndCalendarTests: XCTestCase {
    private let me = "me"
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func event(_ id: String, owner: String, groups: [String] = [], people: [String] = [],
                       rsvps: [String: Bool] = [:]) -> PEvent {
        PEvent(id: id, start: start, title: id, time: "", ownerId: owner,
               rsvps: rsvps, sharedGroupIds: groups, sharedUserIds: people)
    }

    // MARK: - What goes in the Plannit calendar

    func testOnlyPlansYoureInReachThePhoneCalendar() {
        let events = [
            event("mine-private", owner: me),
            event("mine-group-going", owner: me, groups: ["g"]),
            event("mine-group-declined", owner: me, groups: ["g"], rsvps: [me: false]),
            event("their-invitation", owner: "maya", groups: ["g"]),
            event("their-plan-accepted", owner: "maya", groups: ["g"], people: [me], rsvps: [me: true]),
            event("their-plan-declined", owner: "maya", groups: ["g"], rsvps: [me: false]),
            event("shared-with-me", owner: "maya", people: [me]),
        ]

        let copied = Set(AppModel.calendarCopies(of: events, for: me).map(\.id))

        XCTAssertEqual(copied, ["mine-private", "mine-group-going", "their-plan-accepted", "shared-with-me"],
                       "an unanswered invitation or a declined plan must not sit in someone's calendar")
    }

    func testAPlanThatDisappearsFromTheLoadLeavesTheCopySet() {
        let before = [event("plan", owner: "maya", groups: ["g"], people: [me], rsvps: [me: true])]
        XCTAssertEqual(AppModel.calendarCopies(of: before, for: me).count, 1)
        // The owner deleted it: the next load no longer contains it, so the
        // mirror is handed nothing and removes the copy.
        XCTAssertTrue(AppModel.calendarCopies(of: [], for: me).isEmpty)
    }

    // MARK: - Deleting an account

    func testTheAvatarIsDeletedThroughTheStorageAPI() async throws {
        StubTransport.reset()
        defer { StubTransport.reset() }
        StubTransport.on("/storage/v1/object/avatars/", body: "{}")
        let client = StubTransport.client(userId: "u1")

        try await client.deleteObject(bucket: "avatars", path: "u1/avatar.jpg")

        let request = try XCTUnwrap(StubTransport.requests(containing: "/storage/v1/object/avatars/u1/avatar.jpg").first)
        XCTAssertEqual(request.httpMethod, "DELETE")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token",
                       "only the owner may delete their folder, so the request carries their token")
    }

    func testAccountDeletionIsOneAuthorisedCall() async throws {
        StubTransport.reset()
        defer { StubTransport.reset() }
        StubTransport.on("/rpc/delete_my_account", body: "")
        let client = StubTransport.client(userId: "u1")

        try await client.rpcVoid("delete_my_account", args: EmptyArgs())

        let request = try XCTUnwrap(StubTransport.requests(containing: "/rpc/delete_my_account").first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(StubTransport.sent(to: "delete_my_account"), "{}",
                       "no user id is sent: the function deletes whoever is signed in")
    }
}
