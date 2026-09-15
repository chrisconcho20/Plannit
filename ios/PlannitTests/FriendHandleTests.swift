import XCTest
@testable import Plannit

// Finding a friend by `username#code` (migration 0019): what the app accepts as
// a handle, what it sends, and what a username may be.

@MainActor
final class FriendHandleTests: XCTestCase {

    // MARK: - Parsing what someone typed

    func testAHandleSplitsIntoUsernameAndCode() throws {
        let handle = try XCTUnwrap(FriendHandle.parse("Maya#K7M2QX"))
        XCTAssertEqual(handle.username, "Maya")
        XCTAssertEqual(handle.code, "K7M2QX")
    }

    func testCapitalsAndSpacesAreForgiven() throws {
        let handle = try XCTUnwrap(FriendHandle.parse("  Maya Ellis #k7m 2qx "))
        XCTAssertEqual(handle.username, "Maya Ellis", "a username can contain spaces")
        XCTAssertEqual(handle.code, "K7M2QX", "codes are stored uppercase")
    }

    func testLookAlikeLettersReadAsTheDigitsTheyResemble() {
        XCTAssertEqual(FriendHandle.normalizedCode("O1LI00"), "011100")
        XCTAssertEqual(FriendHandle.normalizedCode("oil9zz"), "0119ZZ")
    }

    func testIncompleteOrImpossibleHandlesAreRefusedBeforeAnyLookup() {
        XCTAssertNil(FriendHandle.parse("Maya"), "no code")
        XCTAssertNil(FriendHandle.parse("#K7M2QX"), "no username")
        XCTAssertNil(FriendHandle.parse("Maya#K7M2Q"), "five characters")
        XCTAssertNil(FriendHandle.parse("Maya#K7M2QXA"), "seven characters")
        XCTAssertNil(FriendHandle.parse("Maya#K7M2QU"), "U is not in the alphabet")
        XCTAssertNil(FriendHandle.parse("Maya#K7-2QX"), "punctuation")
        XCTAssertNil(FriendHandle.parse("maya@example.com"),
                     "an email is no longer a way to find someone")
    }

    func testTheAlphabetIsThirtyTwoUnambiguousCharacters() {
        let alphabet = FriendHandle.alphabet
        XCTAssertEqual(alphabet.count, 32)
        XCTAssertEqual(Set(alphabet).count, 32)
        for missing in "ILOU" { XCTAssertFalse(alphabet.contains(missing)) }
    }

    func testFormattingRoundTrips() throws {
        let text = FriendHandle.format(username: "Theo", code: "0A1B2C")
        XCTAssertEqual(text, "Theo#0A1B2C")
        XCTAssertEqual(FriendHandle.parse(text)?.code, "0A1B2C")
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

        let person = try await repo.findPerson(username: "Maya", code: "K7M2QX")

        XCTAssertEqual(person?.id, "maya")
        XCTAssertEqual(person?.hue, .rose, "the result shows their chosen face before you add them")
        let body = try XCTUnwrap(StubTransport.sent(to: "find_profile_by_handle"))
        XCTAssertTrue(body.contains("\"p_username\":\"Maya\""), body)
        XCTAssertTrue(body.contains("\"p_code\":\"K7M2QX\""), body)
    }

    func testARateLimitedLookupIsRecognisedAsOne() async {
        StubTransport.reset()
        defer { StubTransport.reset() }
        StubTransport.on("/rpc/find_profile_by_handle", status: 429,
                         body: #"{"code":"rate_limited","message":"Too many requests. Try again shortly."}"#)
        let repo = SupabaseRepository(client: StubTransport.client())

        do {
            _ = try await repo.findPerson(username: "Maya", code: "K7M2QX")
            XCTFail("a 429 must not read as 'nobody has that handle'")
        } catch {
            XCTAssertTrue(AppModel.isRateLimited(error))
        }
        XCTAssertFalse(AppModel.isRateLimited(SupabaseError.http(403, "")))
    }

    func testNobodyMatchingIsNotAnError() async throws {
        StubTransport.reset()
        defer { StubTransport.reset() }
        StubTransport.on("/rpc/find_profile_by_handle", body: "[]")
        let repo = SupabaseRepository(client: StubTransport.client())

        let person = try await repo.findPerson(username: "Nobody", code: "ZZZZZZ")
        XCTAssertNil(person)
    }
}
