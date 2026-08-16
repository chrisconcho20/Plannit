import Foundation
import Realtime

// RealtimeService — live updates over Supabase Broadcast (decision D-16).
//
// One private channel per group, topic `group:<uuid>`, authorised by the policy
// on realtime.messages in migration 0006. The server sends a hint ("proposals
// changed here"), never row data; this turns that into the matching narrow
// refresh. The polling in LiveRefresh stays as the safety net — if the socket
// is down, or the migration hasn't been applied, the app is merely slower.

@MainActor
final class RealtimeService {
    /// What changed, in the group it changed in.
    enum Change: String { case proposals, events, groups }

    private var client: RealtimeClientV2?
    private var channels: [String: RealtimeChannelV2] = [:]
    private var listeners: [String: Task<Void, Never>] = [:]

    var onChange: ((Change) -> Void)?

    var isConnected: Bool { client != nil }

    /// Subscribe to exactly these groups: joins what's new, drops what's gone,
    /// leaves the rest alone (re-subscribing on every load would churn the
    /// socket every time someone votes).
    func sync(groupIds: [String]) async {
        guard Config.isLiveBackend, !groupIds.isEmpty else {
            await stop()
            return
        }

        let client = client ?? makeClient()
        self.client = client

        let wanted = Set(groupIds)
        for id in wanted.subtracting(channels.keys) {
            await join(id, on: client)
        }
        for id in Set(channels.keys).subtracting(wanted) {
            await leave(id)
        }
    }

    func stop() async {
        for id in channels.keys { await leave(id) }
        client?.disconnect()
        client = nil
    }

    // MARK: - Plumbing

    private func makeClient() -> RealtimeClientV2 {
        let url = URL(string: Config.supabaseURL)!.appendingPathComponent("realtime/v1")
        return RealtimeClientV2(
            url: url,
            options: RealtimeClientOptions(
                headers: ["apikey": Config.supabaseAnonKey],
                // The SDK asks for a token whenever it connects or reconnects,
                // and we answer with a refreshed one. That's the whole fix for
                // the classic footgun where a socket outlives its JWT and gets
                // dropped — we never have to remember to push a new token.
                accessToken: { await SupabaseClient.shared.currentToken() }
            )
        )
    }

    private func join(_ groupId: String, on client: RealtimeClientV2) async {
        let channel = client.channel("group:\(groupId)") { config in
            config.isPrivate = true          // without this, the RLS policy isn't applied
        }
        // Callbacks must be registered before subscribing — the SDK warns
        // (and drops early messages) otherwise.
        let stream = channel.broadcastStream(event: "change")
        channels[groupId] = channel

        listeners[groupId] = Task { [weak self] in
            for await payload in stream {
                guard !Task.isCancelled else { return }
                let kind = (payload["payload"]?.objectValue?["kind"]?.stringValue)
                    ?? payload["kind"]?.stringValue
                guard let change = kind.flatMap(Change.init(rawValue:)) else { continue }
                self?.onChange?(change)
            }
        }

        await channel.subscribe()
        Log.sync("realtime: joined group topic")
    }

    private func leave(_ groupId: String) async {
        listeners[groupId]?.cancel()
        listeners[groupId] = nil
        if let channel = channels[groupId] {
            await client?.removeChannel(channel)
        }
        channels[groupId] = nil
    }
}
