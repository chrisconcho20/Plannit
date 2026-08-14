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

    static func save(_ data: Data, for key: String) {
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
        SecItemAdd(query as CFDictionary, nil)
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
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }

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
