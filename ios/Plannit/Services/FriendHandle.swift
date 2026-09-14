import Foundation

// FriendHandle — how one person finds another: `username#482913`.
//
// The username is the name someone chose and is what the app shows everywhere.
// The 6-digit code is permanent and unique across all accounts (migration 0019),
// so it survives a rename; it's shown only on your own You tab, as the thing to
// give someone who wants to add you. Looking someone up needs both halves.

enum FriendHandle {
    static let codeLength = 6

    /// "Maya#482913".
    static func format(username: String, code: String) -> String {
        "\(username)#\(code)"
    }

    /// Split what someone typed into a username and a code. Forgiving about
    /// spaces and a pasted handle ("Maya Ellis #482 913"); strict about the code
    /// being exactly six digits. Nil when either half is missing.
    static func parse(_ text: String) -> (username: String, code: String)? {
        guard let hash = text.lastIndex(of: "#") else { return nil }
        let username = text[..<hash].trimmingCharacters(in: .whitespacesAndNewlines)
        let code = text[text.index(after: hash)...].filter { !$0.isWhitespace }
        guard !username.isEmpty, code.count == codeLength, code.allSatisfy(\.isASCIIDigit)
        else { return nil }
        return (username, String(code))
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

private extension Character {
    var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}
