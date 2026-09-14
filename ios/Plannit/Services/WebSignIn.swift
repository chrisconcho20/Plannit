import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

// WebSignIn — sign-in providers that only offer a web page (Google, today).
//
// Google's native iOS path needs the GoogleSignIn SDK; this project keeps its
// backend client dependency-free (AGENTS.md), so Google runs through Supabase's
// own OAuth page in ASWebAuthenticationSession instead. That page redirects to
// plannit://auth-callback with a one-time code, exchanged using the PKCE
// verifier made here (RFC 7636).

enum PKCE {
    /// 32 random bytes as base64url: 43 characters, inside RFC 7636's 43–128.
    static func makeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URL(Data(bytes))
    }

    /// The S256 challenge the server stores until the code comes back.
    static func challenge(for verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

@MainActor
final class WebSignIn: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let callbackScheme = "plannit"
    static let redirectURL = "plannit://auth-callback"

    enum Failure: Error {
        case cancelled
        /// The redirect came back without a code — usually the provider or the
        /// Supabase project refused, and says why in `error_description`.
        case refused(String?)
    }

    private var session: ASWebAuthenticationSession?

    /// Show the provider's page and return the code its redirect carries.
    func authorize(url: URL) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url, callbackURLScheme: Self.callbackScheme
            ) { callback, error in
                if let error = error as? ASWebAuthenticationSessionError,
                   error.code == .canceledLogin {
                    continuation.resume(throwing: Failure.cancelled)
                } else if let error {
                    continuation.resume(throwing: error)
                } else if let callback, let code = Self.value("code", in: callback) {
                    continuation.resume(returning: code)
                } else {
                    let reason = callback.flatMap { Self.value("error_description", in: $0) }
                    continuation.resume(throwing: Failure.refused(reason))
                }
            }
            session.presentationContextProvider = self
            self.session = session
            if !session.start() { continuation.resume(throwing: Failure.refused(nil)) }
        }
    }

    /// A query item from the redirect. Supabase can also put errors in the
    /// fragment, so both are read.
    static func value(_ name: String, in url: URL) -> String? {
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let hit = comps?.queryItems?.first(where: { $0.name == name })?.value { return hit }
        guard let fragment = comps?.fragment else { return nil }
        return URLComponents(string: "?\(fragment)")?.queryItems?
            .first(where: { $0.name == name })?.value
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
