import Foundation

// A dependency-free Supabase client over URLSession — auth (Sign in with Apple),
// PostgREST select/insert, and Edge Function invoke. Matches the REST contracts
// in docs/backend/api-contract.md. No SPM package needed.

// MARK: - DTOs

struct SupabaseSession: Decodable {
    let access_token: String
    let refresh_token: String
    let user: SupabaseUser
}
struct SupabaseUser: Decodable { let id: String }

struct GroupDTO: Decodable, Identifiable {
    let id: String
    let name: String
    let owner_id: String
    let avatar_url: String?
    let group_memberships: [MembershipEmbedDTO]?   // PostgREST embedded resource
}
struct MembershipEmbedDTO: Decodable {
    let profiles: ProfileEmbedDTO?
}
struct ProfileEmbedDTO: Decodable {
    let display_name: String?
}

struct NewGroupInsert: Encodable {
    let name: String
    let owner_id: String
}

struct EventDTO: Decodable, Identifiable {
    let id: String
    let title: String
    let notes: String?
    let location: String?
    let start_at: String
    let end_at: String
    let all_day: Bool
    let source: String
}

struct BusyBlockInsert: Encodable {
    let user_id: String
    let start_at: String   // ISO-8601
    let end_at: String
}

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
}

// MARK: - Client

enum SupabaseError: Error { case notConfigured, http(Int, String), decoding }

@MainActor
final class SupabaseClient {
    static let shared = SupabaseClient()
    private let session = URLSession.shared

    private(set) var accessToken: String?
    private(set) var userId: String?

    nonisolated init() {}

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
        accessToken = s.access_token
        userId = s.user.id
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
        accessToken = s.access_token
        userId = s.user.id
        return s.user.id
    }

    var isSignedIn: Bool { accessToken != nil }

    func signOut() { accessToken = nil; userId = nil }

    // MARK: PostgREST
    func select<T: Decodable>(_ table: String, columns: String = "*") async throws -> T {
        guard let baseURL, let token = accessToken else { throw SupabaseError.notConfigured }
        var comps = URLComponents(url: baseURL.appendingPathComponent("rest/v1/\(table)"),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "select", value: columns)]
        var req = URLRequest(url: comps.url!)
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await send(req)
    }

    func insert<T: Encodable>(_ table: String, values: T) async throws {
        guard let baseURL, let token = accessToken else { throw SupabaseError.notConfigured }
        var req = URLRequest(url: baseURL.appendingPathComponent("rest/v1/\(table)"))
        req.httpMethod = "POST"
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = try JSONEncoder().encode(values)
        _ = try await sendRaw(req)
    }

    // MARK: Edge Functions
    func invokeFunction<Req: Encodable, Res: Decodable>(_ name: String, body: Req) async throws -> Res {
        guard let baseURL, let token = accessToken else { throw SupabaseError.notConfigured }
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
    private func sendRaw(_ req: URLRequest) async throws -> Data {
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw SupabaseError.http(-1, "no response") }
        guard (200..<300).contains(http.statusCode) else {
            throw SupabaseError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }
}
