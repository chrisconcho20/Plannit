import AuthenticationServices
import SwiftUI

// ProviderButtons — "Continue with Apple" and "Continue with Google", drawn to
// each company's own rules rather than the design system's, and sized to match
// each other.
//
// Apple: the system SignInWithAppleButton, which draws Apple's logo and wording
// itself. App Review expects that button or a close copy of it, so it isn't
// rebuilt here.
//
// Google: a custom button in Google's light theme (identity branding guidelines):
// white fill, 1pt #747775 stroke, #1F1F1F text, and the standard-colour "G" from
// Google's signin-assets download at its native 20pt, unrecoloured.

enum ProviderButton {
    static let height: CGFloat = 50
    static let shape = RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
}

struct AppleSignInButton: View {
    var onRequest: (ASAuthorizationAppleIDRequest) -> Void
    var onCompletion: (Result<ASAuthorization, Error>) -> Void

    var body: some View {
        SignInWithAppleButton(.continue, onRequest: onRequest, onCompletion: onCompletion)
            .signInWithAppleButtonStyle(.black)
            .frame(height: ProviderButton.height)
            .clipShape(ProviderButton.shape)
    }
}

struct GoogleSignInButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image("GoogleG")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
                Text("Continue with Google")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color(hex: "1F1F1F"))
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: ProviderButton.height)
            .background(Color.white, in: ProviderButton.shape)
            .overlay(ProviderButton.shape.strokeBorder(Color(hex: "747775"), lineWidth: 1))
            .contentShape(ProviderButton.shape)
        }
        .buttonStyle(ProviderPressStyle())
        .accessibilityLabel("Continue with Google")
    }
}

/// A light dim on press. Google's colours can't change, so no tint.
private struct ProviderPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.7 : 1)
    }
}
