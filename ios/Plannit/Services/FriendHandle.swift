import Foundation

// FriendHandle — how one person finds another: `username#K7M2QX`.
//
// The username is the name someone chose and is what the app shows everywhere.
// The 6-character code is permanent and unique across all accounts (migration
// 0019), so it survives a rename; it's shown only on your own You tab, as the
// thing to give someone who wants to add you. Looking someone up needs both.
//
// Codes use Crockford's base32 alphabet: digits and capital letters without
// I, L, O and U — the ones people misread from a screenshot or mishear aloud.
// 32^6 = 1,073,741,824 codes. Capitals don't matter, and the look-alikes are
// read as what they were mistaken for (O → 0, I and L → 1).

enum FriendHandle {
    static let codeLength = 6
    static let alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

    /// "Maya#K7M2QX".
    static func format(username: String, code: String) -> String {
        "\(username)#\(code)"
    }

    /// Split what someone typed into a username and a normalised code.
    /// Forgiving about spaces, capitals and look-alike characters; strict about
    /// the code being six characters from the alphabet. Nil when either half is
    /// missing.
    static func parse(_ text: String) -> (username: String, code: String)? {
        guard let hash = text.lastIndex(of: "#") else { return nil }
        let username = text[..<hash].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty,
              let code = normalizedCode(String(text[text.index(after: hash)...]))
        else { return nil }
        return (username, code)
    }

    /// "k7m 2qx" → "K7M2QX"; "o1l..." → "011...". Nil if it can't be a code.
    static func normalizedCode(_ raw: String) -> String? {
        let code = raw.filter { !$0.isWhitespace }.uppercased()
            .replacingOccurrences(of: "O", with: "0")
            .replacingOccurrences(of: "I", with: "1")
            .replacingOccurrences(of: "L", with: "1")
        guard code.count == codeLength, code.allSatisfy({ alphabet.contains($0) }) else {
            return nil
        }
        return code
    }
}

enum UsernameRules {
    /// Matches `profiles_username_valid` (0019).
    static let maxLength = 32

    /// What's wrong with a username, or nil.
    static func problem(_ username: String) -> String? {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Choose a username." }
        if trimmed.contains("#") { return "A username can't contain #." }
        if trimmed.count > maxLength { return "Keep your username to \(maxLength) characters." }
        return nil
    }

    /// A name from somewhere we don't control (Apple, an email address) made
    /// to fit: no `#`, trimmed, capped.
    static func sanitized(_ name: String) -> String {
        String(name.replacingOccurrences(of: "#", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(maxLength))
    }

    /// Keep a text field inside the rules as it's typed.
    static func limitTyping(_ text: String) -> String {
        String(text.replacingOccurrences(of: "#", with: "").prefix(maxLength))
    }
}
