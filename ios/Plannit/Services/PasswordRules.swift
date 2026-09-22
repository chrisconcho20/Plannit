import Foundation

// PasswordRules — what the app checks before a new password goes to the server.
//
// The server has the final say (Authentication → Providers → Email → minimum
// length); checking here only saves a round trip and lets the screen say what's
// wrong while the person is still typing.

enum PasswordRules {
    /// Must match Authentication → Providers → Email → minimum password length
    /// in the dashboard; the server is what actually enforces it. Eight rather
    /// than Supabase's default six, which the security review called out.
    static let minimumLength = 8

    /// The first thing wrong with a new password and its confirmation, or nil.
    static func problem(_ password: String, confirm: String) -> String? {
        if password.count < minimumLength {
            return "Use at least \(minimumLength) characters for the password."
        }
        if password != confirm { return "The passwords don't match." }
        return nil
    }

    /// Show a mismatch only once the second entry is as long as the first —
    /// flagging it on every keystroke of a half-typed confirmation is noise.
    static func showMismatch(_ password: String, confirm: String) -> Bool {
        !confirm.isEmpty && confirm.count >= password.count && confirm != password
    }
}
