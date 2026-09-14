import AuthenticationServices
import CryptoKit
import Foundation
import Security

// Sign in with Apple, as the pieces SignInWithAppleButton needs around it.
//
// The button runs Apple's sheet itself; this supplies the nonce it's given and
// reads the result. Supabase's id_token grant takes the raw nonce and checks it
// against the SHA-256 that Apple signed into the token, so a token lifted from
// one sign-in can't be replayed into another.

enum AppleSignIn {
    struct Credential {
        let idToken: String
        /// Only present the first time someone signs in to Plannit with Apple —
        /// Apple never sends it again, so it has to be saved then or not at all.
        let fullName: String?
    }

    static func makeNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        while result.count < length {
            var random: UInt8 = 0
            _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            // Rejection sampling keeps the characters uniformly likely.
            if random < UInt8(charset.count) { result.append(charset[Int(random)]) }
        }
        return result
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func credential(from authorization: ASAuthorization) -> Credential? {
        guard let apple = authorization.credential as? ASAuthorizationAppleIDCredential,
              let data = apple.identityToken,
              let token = String(data: data, encoding: .utf8) else { return nil }
        let name = apple.fullName.map { PersonNameComponentsFormatter().string(from: $0) }
        return Credential(idToken: token, fullName: name?.isEmpty == false ? name : nil)
    }
}
