import Foundation
@testable import Plannit

// A fake Supabase, close enough to be useful.
//
// Everything below exists because the expensive bugs in this project have all
// been at the boundary — what we send, what PostgREST sends back, and what the
// decoder makes of it — and none of them were reachable from a test. A stubbed
// URLProtocol lets a test assert on the exact request and hand back the exact
// bytes the real server would, including the awkward ones (an empty body, a
// 403 with an RLS message).

final class StubTransport: URLProtocol {
    /// One canned answer.
    struct Response {
        var status = 200
        var body = "[]"
        /// Matched against the request's path + query, so a test can answer
        /// several endpoints in one exchange.
        var match: (URLRequest) -> Bool
    }

    /// Set before the call, read after it.
    static var responses: [Response] = []
    static var recorded: [URLRequest] = []
    /// Bodies, separately: URLProtocol strips `httpBody` on the copy it hands
    /// back, so `sent(...)` reads from here instead of chasing a nil.
    static var recordedBodies: [String: Data] = [:]

    static func reset() {
        responses = []
        recorded = []
        recordedBodies = [:]
    }

    /// Queue an answer for any request whose URL contains `path`.
    static func on(_ path: String, status: Int = 200, body: String = "[]") {
        responses.append(Response(status: status, body: body) {
            ($0.url?.absoluteString ?? "").contains(path)
        })
    }

    // MARK: Reading back what happened

    static func requests(containing path: String) -> [URLRequest] {
        recorded.filter { ($0.url?.absoluteString ?? "").contains(path) }
    }

    static func sent(to path: String) -> String? {
        guard let key = recordedBodies.keys.first(where: { $0.contains(path) }),
              let data = recordedBodies[key] else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// A session wired to this stub and nothing else.
    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubTransport.self]
        return URLSession(configuration: config)
    }

    /// A client pointed at a fake project, already "signed in".
    @MainActor
    static func client(userId: String = "me") -> SupabaseClient {
        let client = SupabaseClient(session: session(),
                                    url: "https://stub.supabase.co", anonKey: "anon-key")
        client.useSession(accessToken: "test-token", userId: userId)
        return client
    }

    // MARK: URLProtocol

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        // `httpBody` is nil on the request URLProtocol receives when the body
        // was set as a stream, which URLSession does above a few bytes — read
        // the stream when that happens or half the assertions silently pass.
        let body = request.httpBody ?? Self.drain(request.httpBodyStream)
        Self.recorded.append(request)
        if let url = request.url?.absoluteString, let body { Self.recordedBodies[url] = body }

        let answer = Self.responses.first { $0.match(request) }
            ?? Response(status: 200, body: "[]", match: { _ in true })
        let response = HTTPURLResponse(url: request.url!, statusCode: answer.status,
                                       httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(answer.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func drain(_ stream: InputStream?) -> Data? {
        guard let stream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let size = 4096
        var buffer = [UInt8](repeating: 0, count: size)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: size)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data.isEmpty ? nil : data
    }
}
