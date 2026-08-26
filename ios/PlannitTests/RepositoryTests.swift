import XCTest
@testable import Plannit

// The boundary: what we send to PostgREST, what it sends back, and what the
// repository makes of it.
//
// Every test here corresponds to something that was either a real bug on a real
// phone or is one line away from becoming one. The suite was 89 tests and green
// while event creation was completely broken, because nothing exercised this
// layer at all.

@MainActor
final class RepositoryTests: XCTestCase {
    private var client: SupabaseClient!
    private var repo: SupabaseRepository!

    override func setUp() async throws {
        StubTransport.reset()
        client = StubTransport.client()
        repo = SupabaseRepository(client: client)
    }

    override func tearDown() async throws {
        StubTransport.reset()
    }

    // MARK: - Events: the shape of what comes back

    private let eventJSON = """
    [{
      "id": "e1", "owner_id": "maya", "title": "Five-a-side", "notes": null,
      "location": "Hackney Marshes",
      "start_at": "2026-09-05T13:00:00+00:00", "end_at": "2026-09-05T15:00:00+00:00",
      "all_day": false, "source": "plannit", "external_cal_id": null,
      "recurrence_rule": null,
      "event_shares": [{"group_id": "g1", "shared_user_id": null},
                       {"group_id": null, "shared_user_id": "me"}],
      "event_rsvps": [{"user_id": "maya", "response": "going"},
                      {"user_id": "me", "response": "not_going"}]
    }]
    """

    private var soccer: PGroup {
        PGroup(id: "g1", name: "Soccer", hue: .teal,
               members: [PMember(id: "me", name: "You"), PMember(id: "maya", name: "Maya")],
               note: "", ownerId: "maya")
    }

    func testAnEventCarriesItsSharesAndAnswers() async throws {
        StubTransport.on("/events", body: eventJSON)
        let events = try await repo.fetchEvents(groups: [soccer])

        let event = try XCTUnwrap(events.first)
        XCTAssertEqual(event.title, "Five-a-side")
        XCTAssertEqual(event.sharedGroupIds, ["g1"])
        XCTAssertEqual(event.sharedUserIds, ["me"])
        XCTAssertEqual(event.rsvps["maya"], true)
        XCTAssertEqual(event.rsvps["me"], false,
                       "not_going has to survive the round trip — it's the difference "
                       + "between 'said no' and 'hasn't answered'")
        XCTAssertEqual(event.group, "Soccer", "resolved through the shared group")
        XCTAssertEqual(event.hue, .teal, "a shared event takes its group's colour")
    }

    func testTheEventsQueryAsksForEverythingTheMappingReads() async throws {
        StubTransport.on("/events", body: "[]")
        _ = try await repo.fetchEvents(groups: [])

        let url = try XCTUnwrap(StubTransport.requests(containing: "/events").first?.url?
            .absoluteString.removingPercentEncoding)
        // Drop one of these and the field goes quietly nil in the app.
        XCTAssertTrue(url.contains("event_shares(group_id,shared_user_id)"), url)
        XCTAssertTrue(url.contains("event_rsvps(user_id,response)"), url)
        XCTAssertTrue(url.contains("deleted_at") || url.contains("is.null"),
                      "deleted events are tombstones, not rows to show: \(url)")
    }

    func testASharedDeviceEventKeepsItsLinkToThePhone() async throws {
        StubTransport.on("/events", body: """
        [{"id": "e2", "owner_id": "me", "title": "Dentist", "notes": null, "location": null,
          "start_at": "2026-09-06T09:15:00+00:00", "end_at": "2026-09-06T10:00:00+00:00",
          "all_day": false, "source": "device", "external_cal_id": "ext-99",
          "recurrence_rule": null, "event_shares": [], "event_rsvps": []}]
        """)
        let event = try XCTUnwrap(try await repo.fetchEvents(groups: []).first)

        XCTAssertEqual(event.externalCalId, "ext-99")
        XCTAssertTrue(event.isFromDeviceCalendar)
        XCTAssertEqual(event.source, .device)
    }

    func testAnEventSharedWithYouIsNotLabelledPrivate() async throws {
        StubTransport.on("/events", body: eventJSON)
        let event = try XCTUnwrap(try await repo.fetchEvents(groups: [soccer]).first)
        XCTAssertEqual(event.badge, "Shared with you",
                       "it's Maya's event, shared with you — 'Private' was a lie")
    }

    // MARK: - Groups and people

    func testGroupMembersCarryNamesAndChosenAvatars() async throws {
        StubTransport.on("/groups", body: """
        [{"id": "g1", "name": "Soccer", "owner_id": "me", "avatar_url": null,
          "group_memberships": [
            {"user_id": "me",   "profiles": {"id": "me", "display_name": "You",
                                             "avatar_hue": "sky", "avatar_url": null}},
            {"user_id": "kit",  "profiles": {"id": "kit", "display_name": "",
                                             "avatar_hue": null, "avatar_url": null}}
          ]}]
        """)
        let group = try XCTUnwrap(try await repo.fetchGroups().first)

        XCTAssertEqual(group.members.count, 2)
        XCTAssertEqual(group.members.first?.hue, .sky)
        XCTAssertEqual(group.members.last?.name, "Member",
                       "a nameless member still counts — dropping them made groups "
                       + "read '1 of 0 free'")
    }

    func testAnUnknownAvatarHueFallsBackInsteadOfFailingToDecode() async throws {
        StubTransport.on("/groups", body: """
        [{"id": "g1", "name": "Soccer", "owner_id": "me", "avatar_url": null,
          "group_memberships": [{"user_id": "me", "profiles":
            {"id": "me", "display_name": "You", "avatar_hue": "chartreuse",
             "avatar_url": null}}]}]
        """)
        let group = try XCTUnwrap(try await repo.fetchGroups().first)
        XCTAssertNil(group.members.first?.hue,
                     "a value the app doesn't know must not take the whole query down")
    }

    // MARK: - Writes: the request we actually send

    func testCreatingAnEventAsksForTheRowBack() async throws {
        StubTransport.on("/events", body: "[{\"id\": \"new-1\"}]")
        let _: [EventRefDTO] = try await client.insertReturning(
            "events", values: EventInsert(
                owner_id: "me", title: "Dinner", location: nil,
                start_at: "2026-09-05T19:00:00Z", end_at: "2026-09-05T21:00:00Z",
                all_day: false, timezone: "Europe/London", source: "plannit",
                recurrence_rule: nil, external_cal_id: nil))

        let request = try XCTUnwrap(StubTransport.requests(containing: "/events").first)
        XCTAssertEqual(request.httpMethod, "POST")
        // This header is why event creation 403'd for a week: it makes PostgREST
        // run the SELECT policy over the row it just wrote (fixed in 0009). If
        // it ever goes away, the app stops learning the new row's id.
        XCTAssertEqual(request.value(forHTTPHeaderField: "Prefer"), "return=representation")

        let body = try XCTUnwrap(StubTransport.sent(to: "/events"))
        XCTAssertTrue(body.contains("\"owner_id\":\"me\""), body)
        XCTAssertTrue(body.contains("\"source\":\"plannit\""), body)
    }

    func testAvailabilityIsUploadedWithoutAUserId() async throws {
        StubTransport.on("/rpc/replace_busy_blocks", body: "")
        try await client.rpcVoid("replace_busy_blocks", args: ReplaceBusyBlocksArgs(
            p_blocks: [BusyBlockRow(start_at: "2026-09-05T09:00:00Z",
                                    end_at: "2026-09-05T10:00:00Z")]))

        let body = try XCTUnwrap(StubTransport.sent(to: "replace_busy_blocks"))
        XCTAssertTrue(body.contains("p_blocks"), body)
        XCTAssertFalse(body.contains("user_id"),
                       "the function takes the user from auth.uid(); sending one invites "
                       + "the question of whether it's trusted")
    }

    // MARK: - Responses that aren't JSON objects

    func testAVoidFunctionReportsSuccessOnAnEmptyBody() async throws {
        // The regression that matters: PostgREST answers `returns void` with an
        // empty body. Decoding that threw, so `rsvp_to_event` reported failure
        // for a write that had already happened and the app rolled back state
        // the server had changed.
        StubTransport.on("/rpc/rsvp_to_event", status: 200, body: "")
        try await client.rpcVoid("rsvp_to_event",
                                 args: RsvpArgs(p_event: "e1", p_going: true))
    }

    func testAnEmptyBodyStillFailsWhenAResultIsExpected() async {
        StubTransport.on("/rpc/my_friends", status: 200, body: "")
        do {
            let _: [FriendDTO] = try await client.rpc("my_friends", args: EmptyArgs())
            XCTFail("a function whose rows we need must not silently return none")
        } catch let error as SupabaseError {
            guard case .decoding = error else { return XCTFail("wrong error: \(error)") }
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    // MARK: - Failures

    func testAnRLSRefusalSurfacesAsItsStatus() async {
        StubTransport.on("/events", status: 403,
                         body: "{\"message\":\"row-level security\"}")
        do {
            _ = try await repo.fetchEvents(groups: [])
            XCTFail("a 403 must not read as an empty calendar")
        } catch let error as SupabaseError {
            guard case .http(let code, _) = error else { return XCTFail("wrong error: \(error)") }
            XCTAssertEqual(code, 403)
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    func testASignedOutClientDoesNotPretendToWork() async {
        let stranger = SupabaseClient(session: StubTransport.session(), url: "", anonKey: "")
        do {
            let _: [EventDTO] = try await stranger.select("events")
            XCTFail("no config means no request, not an empty result")
        } catch let error as SupabaseError {
            guard case .notConfigured = error else { return XCTFail("wrong error: \(error)") }
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    func testEveryRequestCarriesTheKeyAndTheToken() async throws {
        StubTransport.on("/events", body: "[]")
        _ = try await repo.fetchEvents(groups: [])

        let request = try XCTUnwrap(StubTransport.requests(containing: "/events").first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "anon-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token",
                       "without the user's token PostgREST falls back to the anon role "
                       + "and RLS quietly returns nothing")
    }
}
