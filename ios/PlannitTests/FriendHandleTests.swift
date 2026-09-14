import XCTest
@testable import Plannit

// Finding a friend by `username#code` (migration 0019): what the app accepts as
// a handle, what it sends, and what a username may be.

@MainActor
final class FriendHandleTests: XCTestCase {

    // MARK: - Parsing what someone typed

    func testAHandleSplitsIntoUsernameAndCode() throws {
        let handle = try XCTUnwrap(FriendHandle.parse("Maya#482913"))
        XCTAssertEqual(handle.username, "Maya")
        XCTAssertEqual(handle.code, "482913")
    }

    func testSpacesAroundThePiecesAreForgiven() throws {
        let handle = try XCTUnwrap(FriendHandle.parse("  Maya Ellis #482 913 "))
        XCTAssertEqual(handle.username, "Maya Ellis", "a username can contain spaces")
        XCTAssertEqual(handle.code, "482913", "a code read aloud often gets typed in pairs")
    }

    func testACodeStartingWithZeroKeepsItsZeros() throws {
        XCTAssertEqual(FriendHandle.parse("sam#004210")?.code, "004210")
    }

    func testIncompleteHandlesAreRefusedBeforeAnyLookup() {
        XCTAssertNil(FriendHandle.parse("Maya"), "no code")
        XCTAssertNil(FriendHandle.parse("#482913"), "no username")
        XCTAssertNil(FriendHandle.parse("Maya#48291"), "five digits")
        XCTAssertNil(FriendHandle.parse("Maya#4829130"), "seven digits")
        XCTAssertNil(FriendHandle.parse("Maya#48a913"), "not all digits")
        XCTAssertNil(FriendHandle.parse("maya@example.com"),
                     "an email is no longer a way to find someone")
    }

    func testFormattingRoundTrips() throws {
        let text = FriendHandle.format(username: "Theo", code: "000123")
        XCTAssertEqual(text, "Theo#000123")
        XCTAssertEqual(FriendHandle.parse(text)?.code, "000123")
    }

    // MARK: - Usernames

    func testAUsernameCantHoldTheSeparatorOrRunLong() {
        XCTAssertNil(UsernameRules.problem("Maya Ellis"))
        XCTAssertNotNil(UsernameRules.problem("   "))
        XCTAssertNotNil(UsernameRules.problem("Maya#1"), "# would make the handle ambiguous")
        XCTAssertNotNil(UsernameRules.problem(String(repeating: "a", count: 33)))
        XCTAssertNil(UsernameRules.problem(String(repeating: "a", count: 32)))
    }

    func testANameFromAProviderIsMadeToFit() {
        XCTAssertEqual(UsernameRules.sanitized("  #1 Fan "), "1 Fan")
        XCTAssertEqual(UsernameRules.sanitized(String(repeating: "b", count: 40)).count, 32)
    }

    func testTypingCantGetPastTheRules() {
        XCTAssertEqual(UsernameRules.limitTyping("ma#ya"), "maya")
        XCTAssertEqual(UsernameRules.limitTyping(String(repeating: "c", count: 35)).count, 32)
    }

    // MARK: - The lookup request

    func testTheLookupSendsBothHalvesOfTheHandle() async throws {
        StubTransport.reset()
        defer { StubTransport.reset() }
        StubTransport.on("/rpc/find_profile_by_handle", body: """
        [{"id": "maya", "display_name": "Maya", "avatar_hue": "rose", "avatar_url": null}]
        """)
        let repo = SupabaseRepository(client: StubTransport.client())

        let person = try await repo.findPerson(username: "Maya", code: "482913")

        XCTAssertEqual(person?.id, "maya")
        XCTAssertEqual(person?.hue, .rose, "the result shows their chosen face before you add them")
        let body = try XCTUnwrap(StubTransport.sent(to: "find_profile_by_handle"))
        XCTAssertTrue(body.contains("\"p_username\":\"Maya\""), body)
        XCTAssertTrue(body.contains("\"p_code\":\"482913\""), body)
    }

    func testNobodyMatchingIsNotAnError() async throws {
        StubTransport.reset()
        defer { StubTransport.reset() }
        StubTransport.on("/rpc/find_profile_by_handle", body: "[]")
        let repo = SupabaseRepository(client: StubTransport.client())

        let person = try await repo.findPerson(username: "Nobody", code: "000000")
        XCTAssertNil(person)
    }
}
