import Foundation
import Security

// A minimal Keychain wrapper for the Supabase session. The session is the one
// piece of state that must outlive the process: holding it in memory only meant
// every relaunch signed you out.
//
// Keychain rather than UserDefaults because these are credentials — a refresh
// token is as good as a password until it's revoked.

enum Keychain {
    private static let service = "com.plannit.app.session"

    @discardableResult
    static func save(_ data: Data, for key: String) -> Bool {
        // Delete first: SecItemUpdate needs a different query shape, and an
        // add-after-delete is atomic enough for a single-writer app.
        delete(key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            // Available after first unlock so a background refresh can read it,
            // but never synced to iCloud or included in backups to other devices.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess { return true }
        if isUnavailable(status) {
            UserDefaults.standard.set(data, forKey: fallbackKey(key))
            return true
        }
        return false
    }

    static func load(_ key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data { return data }
        if isUnavailable(status) { return UserDefaults.standard.data(forKey: fallbackKey(key)) }
        return nil
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
        // Always clear the fallback too — signing out must forget everything,
        // wherever it ended up.
        UserDefaults.standard.removeObject(forKey: fallbackKey(key))
    }

    // MARK: Unsigned simulator fallback
    //
    // An app built without entitlements — our CI test host, and the unsigned
    // simulator builds Appetize runs — gets errSecMissingEntitlement from every
    // Keychain call. Rather than silently lose the session there, fall back to
    // UserDefaults *only* in that case. A signed build (any real device, free
    // team included) never takes this path, so the token stays in the Keychain
    // where it belongs.

    private static func isUnavailable(_ status: OSStatus) -> Bool {
        status == errSecMissingEntitlement || status == errSecNotAvailable
    }

    private static func fallbackKey(_ key: String) -> String { "plannit.unsigned.\(key)" }

    // MARK: Codable convenience

    static func save<T: Encodable>(_ value: T, for key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        save(data, for: key)
    }

    static func load<T: Decodable>(_ type: T.Type, for key: String) -> T? {
        guard let data = load(key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
