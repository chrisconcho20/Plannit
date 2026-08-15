import Foundation

// A dependency-free Supabase client over URLSession — auth (Sign in with Apple),
// PostgREST select/insert, and Edge Function invoke. Matches the REST contracts
// in docs/backend/api-contract.md. No SPM package needed.

// MARK: - DTOs

struct SupabaseSession: Decodable {
    let access_token: String
    let refresh_token: String
    let expires_in: Int?
    let user: SupabaseUser
}

/// GoTrue answers a sign-up one of two ways depending on the project's "confirm
/// email" setting: with a session (straight in) or with just a user (go check
/// your inbox). Decode leniently and let the caller tell the difference.
struct SignUpResponse: Decodable {
    let access_token: String?
    let refresh_token: String?
    let expires_in: Int?
    let user: SupabaseUser?
    let id: String?
    let confirmation_sent_at: String?

    var session: SupabaseSession? {
        guard let access_token, let refresh_token, let user else { return nil }
        return SupabaseSession(access_token: access_token, refresh_token: refresh_token,
                               expires_in: expires_in, user: user)
    }
}

/// What we keep in the Keychain between launches.
struct StoredSession: Codable {
    let accessToken: String
    let refreshToken: String
    let userId: String
    let email: String?
    let expiresAt: Date

    /// Treat a token as spent a minute early — a request that starts valid can
    /// still arrive expired.
    var isFresh: Bool { expiresAt.timeIntervalSinceNow > 60 }
}
struct SupabaseUser: Decodable {
    let id: String
    let email: String?
}

struct ProfileDTO: Decodable {
    let id: String
    let display_name: String
    let timezone: String?
}
struct DisplayNameUpdate: Encodable { let display_name: String }
struct SignUpMetadata: Encodable {
    let display_name: String
    let timezone: String
}
struct SignUpBody: Encodable {
    let email: String
    let password: String
    let data: SignUpMetadata
}
struct ProfileInsert: Encodable {
    let id: String
    let display_name: String
    let timezone: String
}

struct GroupDTO: Decodable, Identifiable {
    let id: String
    let name: String
    let owner_id: String
    let avatar_url: String?
    let group_memberships: [MembershipEmbedDTO]?   // PostgREST embedded resource
}
struct MembershipEmbedDTO: Decodable {
    let user_id: String?
    let profiles: ProfileEmbedDTO?
}
struct ProfileEmbedDTO: Decodable {
    let id: String?
    let display_name: String?
}

struct NewGroupInsert: Encodable {
    let name: String
    let owner_id: String
}
struct GroupRefDTO: Decodable { let id: String }
struct MembershipInsert: Encodable {
    let group_id: String
    let user_id: String
    let role: String       // "owner" | "admin" | "member"
}

struct EventDTO: Decodable, Identifiable {
    let id: String
    let owner_id: String
    let title: String
    let notes: String?
    let location: String?
    let start_at: String
    let end_at: String
    let all_day: Bool
    let source: String
    let event_shares: [EventShareEmbedDTO]?   // only one FK to events — safe to embed
}
struct EventShareEmbedDTO: Decodable {
    let group_id: String?
    let shared_user_id: String?
}

struct EventInsert: Encodable {
    let owner_id: String
    let title: String
    let location: String?
    let start_at: String   // ISO-8601
    let end_at: String
    let all_day: Bool
    let timezone: String
    let source: String     // "plannit" | "device"
}

struct BusyBlockInsert: Encodable {
    let user_id: String
    let start_at: String   // ISO-8601
    let end_at: String
}

// A proposal with its group and votes. Slots are fetched separately — see
// SupabaseRepository.fetchProposals for why.
struct ProposalRowDTO: Decodable, Identifiable {
    let id: String
    let group_id: String
    let created_by: String
    let title: String
    let status: String
    let finalized_slot_id: String?
    let created_at: String?
    let constraints: StoredConstraintsDTO?
    let groups: GroupDTO?
    let votes: [VoteDTO]?
}
/// The `constraints` jsonb as stored by find-slots — enough to describe the ask.
struct StoredConstraintsDTO: Decodable {
    let allowedWeekdays: [Int]?
    let dayStartMinutes: Int?
    let dayEndMinutes: Int?
    let durationMinutes: Int?
}
struct ProposalSlotDTO: Decodable, Identifiable {
    let id: String
    let proposal_id: String?
    let start_at: String
    let end_at: String
    let score: Int
    let available_user_ids: [String]?
}
struct VoteDTO: Decodable {
    let slot_id: String
    let user_id: String
    let response: String
}
struct VoteInsert: Encodable {
    let proposal_id: String
    let slot_id: String
    let user_id: String
    let response: String   // "yes" | "no" | "maybe"
}
struct ProposalFinalizeUpdate: Encodable {
    let finalized_slot_id: String
    let status: String     // "finalized"
}
struct EventUpdate: Encodable {
    let title: String
    let location: String?
    let start_at: String
    let end_at: String
    let all_day: Bool
}
/// Soft delete — the sync contract wants a tombstone, not a vanished row.
struct EventTombstone: Encodable { let deleted_at: String }
struct GroupRename: Encodable { let name: String }
struct EventShareInsert: Encodable {
    let event_id: String
    let group_id: String
}
/// A share aimed at one person. Separate struct because the table's check
/// constraint allows exactly one target — a group or a user, never both.
struct EventUserShareInsert: Encodable {
    let event_id: String
    let shared_user_id: String
}
struct EventRefDTO: Decodable { let id: String }

// MARK: Activity
struct ActivityDTO: Decodable {
    let kind: String
    let happened_at: String
    let actor_name: String?
    let title: String?
    let subtitle: String?
    let group_id: String?
    let proposal_id: String?
}
struct ActivityArgs: Encodable { let p_limit: Int }

// MARK: Friends
struct FriendDTO: Decodable {
    let id: String
    let display_name: String
}
struct FriendRequestDTO: Decodable {
    let id: String
    let other_id: String
    let display_name: String
    let incoming: Bool
}
struct FriendshipInsert: Encodable {
    let requester_id: String
    let addressee_id: String
    let status: String     // "pending" | "accepted" | "blocked"
}
struct FriendshipStatusUpdate: Encodable { let status: String }
struct EmailLookup: Encodable { let p_email: String }
struct ConfigRowDTO: Decodable { let key: String; let value: Bool }
struct EmptyArgs: Encodable {}

// Mirrors the Edge Function Constraints (supabase/functions/_shared/scheduler.ts).
struct SlotConstraintsDTO: Encodable {
    let windowStart: Int64
    let windowEnd: Int64
    let allowedWeekdays: [Int]
    let dayStartMinutes: Int
    let dayEndMinutes: Int
    let durationMinutes: Int
    let stepMinutes: Int
    let timezone: String
    let quorum: Int?
}
struct FindSlotsRequest: Encodable {
    let groupId: String
    let title: String
    let constraints: SlotConstraintsDTO
    let maxResults: Int
    let persist: Bool
}
struct FoundSlotDTO: Decodable {
    let start: Int64
    let end: Int64
    let score: Int
    let availableUserIds: [String]
}
struct ProposalRefDTO: Decodable { let id: String }
struct FindSlotsResponse: Decodable {
    let proposal: ProposalRefDTO?   // omitted when persist:false
    let slots: [FoundSlotDTO]
    // Optional so the app keeps working against a not-yet-redeployed function:
    // that older build only ever returned all-free slots, so nil means "true".
    let everyoneFree: Bool?         // false = best-turnout fallback
    let memberCount: Int?
    let quorum: Int?
}

// MARK: - Client

enum SupabaseError: Error { case notConfigured, http(Int, String), decoding }

@MainActor
final class SupabaseClient {
    static let shared = SupabaseClient()
    private let session = URLSession.shared

    private(set) var accessToken: String?
    private(set) var userId: String?
    private(set) var userEmail: String?
    private var refreshToken: String?
    private var expiresAt: Date?

    private static let sessionKey = "supabase.session"

    nonisolated init() {}

    // MARK: Session persistence

    /// Reload the session saved at last sign-in. Returns true when there's
    /// something to work with — an expired access token is fine, `authorized()`
    /// refreshes it before the next request.
    @discardableResult
    func restoreSession() -> Bool {
        guard Config.isLiveBackend,
              let stored = Keychain.load(StoredSession.self, for: Self.sessionKey)
        else { return false }
        accessToken = stored.accessToken
        refreshToken = stored.refreshToken
        userId = stored.userId
        userEmail = stored.email
        expiresAt = stored.expiresAt
        return true
    }

    private func store(_ session: SupabaseSession) {
        accessToken = session.access_token
        refreshToken = session.refresh_token
        userId = session.user.id
        userEmail = session.user.email ?? userEmail
        expiresAt = Date().addingTimeInterval(TimeInterval(session.expires_in ?? 3600))
        guard let expiresAt, let userId else { return }
        Keychain.save(StoredSession(accessToken: session.access_token,
                                    refreshToken: session.refresh_token,
                                    userId: userId, email: userEmail, expiresAt: expiresAt),
                      for: Self.sessionKey)
    }

    /// Swap the refresh token for a new access token. Supabase rotates the
    /// refresh token too, so the result is stored like any other sign-in.
    @discardableResult
    private func refreshSession() async -> Bool {
        guard let baseURL, let token = refreshToken else { return false }
        var comps = URLComponents(url: baseURL.appendingPathComponent("auth/v1/token"),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(["refresh_token": token])

        do {
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  let s = try? JSONDecoder().decode(SupabaseSession.self, from: data)
            else {
                // The refresh token is dead (revoked, or rotated by another
                // device) — drop it so we don't spin retrying.
                clearSession()
                return false
            }
            store(s)
            return true
        } catch {
            return false   // offline: keep the session, try again later
        }
    }

    /// The access token to send, refreshed first if it's about to expire.
    private func authorized() async -> String? {
        if let expiresAt, expiresAt.timeIntervalSinceNow <= 60, refreshToken != nil {
            await refreshSession()
        }
        return accessToken
    }

    /// A token that's good right now, refreshing first if it's about to expire.
    /// The Realtime SDK calls this on every connect and reconnect.
    func currentToken() async -> String? { await authorized() }

    private func clearSession() {
        accessToken = nil; refreshToken = nil; userId = nil
        userEmail = nil; expiresAt = nil
        Keychain.delete(Self.sessionKey)
    }

    var isConfigured: Bool { Config.isLiveBackend }
    private var baseURL: URL? { URL(string: Config.supabaseURL) }
    private var anonKey: String { Config.supabaseAnonKey }

    // MARK: Auth — exchange an Apple identity token for a Supabase session.
    @discardableResult
    func signInWithApple(idToken: String, nonce: String) async throws -> String {
        guard let baseURL else { throw SupabaseError.notConfigured }
        var comps = URLComponents(url: baseURL.appendingPathComponent("auth/v1/token"),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "grant_type", value: "id_token")]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(
            ["provider": "apple", "id_token": idToken, "nonce": nonce])

        let s: SupabaseSession = try await send(req)
        store(s)
        return s.user.id
    }

    // MARK: Auth — email/password (dev sign-in for browser/simulator testing).
    @discardableResult
    func signInWithEmail(_ email: String, password: String) async throws -> String {
        guard let baseURL else { throw SupabaseError.notConfigured }
        var comps = URLComponents(url: baseURL.appendingPathComponent("auth/v1/token"),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "grant_type", value: "password")]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["email": email, "password": password])

        let s: SupabaseSession = try await send(req)
        store(s)
        return s.user.id
    }

    // MARK: Auth — create an account.
    //
    // `data` becomes raw_user_meta_data, which the handle_new_user trigger reads
    // to fill in the profile — so a new account arrives already named and in the
    // right timezone, and 0005's auto-friend trigger fires with a real name.
    enum SignUpResult { case signedIn, needsEmailConfirmation }

    func signUp(email: String, password: String, displayName: String) async throws -> SignUpResult {
        guard let baseURL else { throw SupabaseError.notConfigured }
        var req = URLRequest(url: baseURL.appendingPathComponent("auth/v1/signup"))
        req.httpMethod = "POST"
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(SignUpBody(
            email: email, password: password,
            data: SignUpMetadata(display_name: displayName,
                                 timezone: TimeZone.current.identifier)))

        let response: SignUpResponse = try await send(req)
        if let session = response.session {
            store(session)
            return .signedIn
        }
        return .needsEmailConfirmation
    }

    var isSignedIn: Bool { accessToken != nil }

    func signOut() { clearSession() }

    // MARK: PostgREST
    /// `query` takes raw PostgREST filters, e.g. `["deleted_at": "is.null",
    /// "order": "start_at.asc"]`.
    func select<T: Decodable>(_ table: String, columns: String = "*",
                              query: [String: String] = [:]) async throws -> T {
        guard let baseURL, let token = await authorized() else { throw SupabaseError.notConfigured }
        var comps = URLComponents(url: baseURL.appendingPathComponent("rest/v1/\(table)"),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "select", value: columns)]
            + query.map { URLQueryItem(name: $0.key, value: $0.value) }
        var req = URLRequest(url: comps.url!)
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await send(req)
    }

    /// PATCH the rows matching `match` (raw PostgREST filters, as above).
    func update<T: Encodable>(_ table: String, values: T, match: [String: String]) async throws {
        guard let baseURL, let token = await authorized() else { throw SupabaseError.notConfigured }
        var comps = URLComponents(url: baseURL.appendingPathComponent("rest/v1/\(table)"),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = match.map { URLQueryItem(name: $0.key, value: $0.value) }
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "PATCH"
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = try JSONEncoder().encode(values)
        _ = try await sendRaw(req)
    }

    func insert<T: Encodable>(_ table: String, values: T) async throws {
        guard let baseURL, let token = await authorized() else { throw SupabaseError.notConfigured }
        var req = URLRequest(url: baseURL.appendingPathComponent("rest/v1/\(table)"))
        req.httpMethod = "POST"
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = try JSONEncoder().encode(values)
        _ = try await sendRaw(req)
    }

    /// Insert and read the rows back (PostgREST `return=representation`) — for
    /// when you need the generated id, e.g. a new group's memberships.
    func insertReturning<T: Encodable, R: Decodable>(_ table: String, values: T) async throws -> R {
        guard let baseURL, let token = await authorized() else { throw SupabaseError.notConfigured }
        var req = URLRequest(url: baseURL.appendingPathComponent("rest/v1/\(table)"))
        req.httpMethod = "POST"
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("return=representation", forHTTPHeaderField: "Prefer")
        req.httpBody = try JSONEncoder().encode(values)
        return try await send(req)
    }

    /// DELETE the rows matching `match` (raw PostgREST filters). RLS decides
    /// whether you're allowed to — a forbidden delete removes nothing.
    func delete(_ table: String, match: [String: String]) async throws {
        guard let baseURL, let token = await authorized() else { throw SupabaseError.notConfigured }
        var comps = URLComponents(url: baseURL.appendingPathComponent("rest/v1/\(table)"),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = match.map { URLQueryItem(name: $0.key, value: $0.value) }
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "DELETE"
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        _ = try await sendRaw(req)
    }

    /// Call a Postgres function. Some things RLS deliberately hides — a
    /// stranger's profile, a pending requester's name — are reachable only
    /// through a SECURITY DEFINER function that scopes the answer to you.
    func rpc<Args: Encodable, Res: Decodable>(_ name: String, args: Args) async throws -> Res {
        guard let baseURL, let token = await authorized() else { throw SupabaseError.notConfigured }
        var req = URLRequest(url: baseURL.appendingPathComponent("rest/v1/rpc/\(name)"))
        req.httpMethod = "POST"
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(args)
        return try await send(req)
    }

    // MARK: Edge Functions
    func invokeFunction<Req: Encodable, Res: Decodable>(_ name: String, body: Req) async throws -> Res {
        guard let baseURL, let token = await authorized() else { throw SupabaseError.notConfigured }
        var req = URLRequest(url: baseURL.appendingPathComponent("functions/v1/\(name)"))
        req.httpMethod = "POST"
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        return try await send(req)
    }

    // MARK: Transport
    private func send<T: Decodable>(_ req: URLRequest) async throws -> T {
        let data = try await sendRaw(req)
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw SupabaseError.decoding }
    }

    @discardableResult
    private func sendRaw(_ req: URLRequest, allowRetry: Bool = true) async throws -> Data {
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw SupabaseError.http(-1, "no response") }

        // A token can expire between the freshness check and the server reading
        // it. One refresh-and-retry turns that into a non-event.
        if http.statusCode == 401, allowRetry, refreshToken != nil,
           await refreshSession(), let token = accessToken {
            var retry = req
            retry.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            return try await sendRaw(retry, allowRetry: false)
        }

        guard (200..<300).contains(http.statusCode) else {
            throw SupabaseError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }
}
