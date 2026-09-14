import AuthenticationServices
import SwiftUI

// Onboarding — Welcome (three value props + Continue with Apple) and the
// calendar-permission screen. Mirrors ui_kits/plannit-ios/Onboarding.jsx.

struct WelcomeView: View {
    var onStart: () -> Void
    var onSignIn: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 14) {
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .fill(Color.actionPrimary)
                    .frame(width: 76, height: 76)
                    .overlay(PIcon("calendar-heart", size: 38, color: .white, weight: .bold))
                    .primaryGlow()
                Text("Plannit").textStyle(.display, color: .textStrong)
                Text("Make plans that actually happen.")
                    .textStyle(.title3, color: .textMuted)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            VStack(spacing: 14) {
                feature("calendar-check", .coral, "One calendar",
                        "Two-way sync with the calendar you already use.")
                feature("lock", .indigo, "Share by group",
                        "Show the right events to the right people — nothing else.")
                feature("wand-sparkles", .teal, "Find the date",
                        "Say “a weekend afternoon” and Plannit finds when everyone’s free.")
            }
            .padding(.horizontal, Space.gutter)
            Spacer()
            VStack(spacing: 10) {
                PlannitButton(title: "Continue with Apple", variant: .primary, size: .lg,
                              icon: "apple", fullWidth: true, action: onStart)
                PlannitButton(title: "I already have an account", variant: .ghost, size: .md,
                              fullWidth: true, action: onSignIn)
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, 8)
        }
    }

    private func feature(_ icon: String, _ hue: GroupHue, _ title: String, _ body: String) -> some View {
        HStack(spacing: 14) {
            Circle().fill(hue.soft).frame(width: 44, height: 44)
                .overlay(PIcon(icon, size: 20, color: hue.color, weight: .semibold))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).textStyle(.headline, color: .textStrong)
                Text(body).textStyle(.footnote, color: .textMuted)
            }
            Spacer(minLength: 0)
        }
    }
}

struct ConnectCalendarView: View {
    var connect: () async -> Void
    var onSkip: () -> Void
    @State private var connecting = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 18) {
                ZStack {
                    Circle().fill(Palette.teal50).frame(width: 128, height: 128)
                    PIcon("calendar-check", size: 56, color: .statusFree, weight: .semibold)
                }
                VStack(spacing: 8) {
                    Text("Connect your calendar").textStyle(.title1, color: .textStrong)
                        .multilineTextAlignment(.center)
                    Text("Plannit reads your events to find times everyone’s free. Your event details stay on your phone — only free/busy is shared.")
                        .textStyle(.subhead, color: .textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Space.gutter)
                }
            }
            Spacer()
            VStack(spacing: 10) {
                PlannitButton(title: connecting ? "Connecting…" : "Connect calendar",
                              variant: .primary, size: .lg, icon: "calendar", fullWidth: true) {
                    connecting = true
                    Task { @MainActor in await connect() }
                }
                .disabled(connecting)
                PlannitButton(title: "Not now", variant: .ghost, size: .md,
                              fullWidth: true, action: onSkip)
                Text("You can turn this on later in You → Your calendar.")
                    .textStyle(.caption, color: .textFaint)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, 8)
        }
    }
}

// The front door of a live build: Apple, Google, or email.
//
// Email is the one path with steps. Creating an account emails a 6-digit code
// that has to come back before the account works (when confirmation is on in
// the Supabase project); signing in afterwards needs only the password. A
// forgotten password is reset with a code the same way, because the app has no
// web page for an emailed link to open.

struct LiveSignInView: View {
    var onSignedIn: () -> Void
    @EnvironmentObject private var model: AppModel

    enum Step: Equatable {
        case form
        /// Confirm a new account.
        case confirm(email: String)
        /// Ask for a reset code.
        case forgot
        case resetCode(email: String)
        case newPassword
    }

    @State private var step: Step = .form
    @State private var creating = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var code = ""
    @State private var busy = false
    @State private var message: String?
    @State private var messageIsError = true
    /// The raw nonce for the Apple request in flight; only its hash goes to Apple.
    @State private var appleNonce = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                    .padding(.top, 40)
                    .padding(.bottom, 28)
                VStack(spacing: 12) {
                    switch step {
                    case .form:                  form
                    case .confirm(let address):  codeEntry(sentTo: address, purpose: .signUp)
                    case .forgot:                forgot
                    case .resetCode(let address): codeEntry(sentTo: address, purpose: .passwordReset)
                    case .newPassword:           newPassword
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.bottom, 32)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .animation(Motion.fast, value: step)
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(Color.actionPrimary).frame(width: 72, height: 72)
                .overlay(PIcon("calendar-heart", size: 36, color: .white, weight: .bold))
                .primaryGlow()
            Text(title).textStyle(.display, color: .textStrong)
            Text(subtitle)
                .textStyle(.subhead, color: .textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.gutter)
        }
    }

    private var title: String {
        switch step {
        case .form:         return "Plannit"
        case .confirm:      return "Check your email"
        case .forgot:       return "Reset password"
        case .resetCode:    return "Check your email"
        case .newPassword:  return "New password"
        }
    }

    private var subtitle: String {
        switch step {
        case .form:
            return creating ? "Make plans that actually happen." : "Welcome back."
        case .confirm(let address), .resetCode(let address):
            return "We sent a 6-digit code to \(address)."
        case .forgot:
            return "We'll email you a code to set a new one."
        case .newPassword:
            return "Choose a password you haven't used here before."
        }
    }

    // MARK: Sign in / create account

    @ViewBuilder
    private var form: some View {
        SignInWithAppleButton(.continue) { request in
            appleNonce = AppleSignIn.makeNonce()
            request.requestedScopes = [.fullName, .email]
            request.nonce = AppleSignIn.sha256(appleNonce)
        } onCompletion: { result in
            run { await model.signInWithApple(result, nonce: appleNonce) }
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
        .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .disabled(busy)

        PlannitButton(title: "Continue with Google", variant: .outline, size: .lg,
                      fullWidth: true) {
            run { await model.signInWithGoogle() }
        }
        .disabled(busy)

        HStack(spacing: 10) {
            Rectangle().fill(Color.hairline).frame(height: 1)
            Text("or use email").textStyle(.caption, color: .textFaint).fixedSize()
            Rectangle().fill(Color.hairline).frame(height: 1)
        }
        .padding(.vertical, 6)

        SegmentedControl(options: [false, true], selection: $creating.animation(Motion.fast)) {
            $0 ? "Create account" : "Sign in"
        }
        .padding(.bottom, 2)
        .onChange(of: creating) { _, _ in message = nil; confirm = "" }

        if creating {
            PTextField(placeholder: "Your name", text: $name, icon: "user")
                .textContentType(.name)
        }
        emailField

        PasswordField(placeholder: creating ? "Password (\(PasswordRules.minimumLength)+ characters)"
                                            : "Password",
                      text: $password,
                      contentType: creating ? .newPassword : .password)
        if creating {
            PasswordField(placeholder: "Confirm password", text: $confirm,
                          contentType: .newPassword, invalid: mismatch)
            if mismatch { hint("The passwords don't match.") }
        }

        messageView

        PlannitButton(title: formButtonTitle, variant: .primary, size: .lg, fullWidth: true) {
            submitForm()
        }
        .disabled(busy || !formReady)
        .opacity(busy || !formReady ? 0.5 : 1)

        if creating {
            Text("Your name is what your groups see. You can change it later.")
                .textStyle(.caption, color: .textFaint)
                .multilineTextAlignment(.center)
        } else {
            PlannitButton(title: "Forgot password?", variant: .ghost, size: .md, fullWidth: true) {
                go(to: .forgot)
            }
        }
    }

    private var mismatch: Bool { PasswordRules.showMismatch(password, confirm: confirm) }

    private var formReady: Bool {
        guard !email.isEmpty, !password.isEmpty else { return false }
        return !creating || (!name.isEmpty && !confirm.isEmpty)
    }

    private var formButtonTitle: String {
        if busy { return creating ? "Creating…" : "Signing in…" }
        return creating ? "Create account" : "Sign in"
    }

    private func submitForm() {
        let address = AppModel.clean(email)
        run {
            creating
                ? await model.signUp(email: address, password: password, confirm: confirm, name: name)
                : await model.signIn(email: address, password: password)
        } onNeedsCode: {
            go(to: .confirm(email: address))
        }
    }

    // MARK: Codes

    @ViewBuilder
    private func codeEntry(sentTo address: String, purpose: SupabaseClient.CodePurpose) -> some View {
        TextField("123456", text: $code)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .monospacedDigit()
            .multilineTextAlignment(.center)
            .frame(minHeight: 60)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                .strokeBorder(Color.lineStrong, lineWidth: 1))
            // Projects can set codes up to 10 digits; 6 is the default.
            .onChange(of: code) { _, typed in
                let clean = String(AppModel.digits(typed).prefix(10))
                if clean != typed { code = clean }
            }
            .accessibilityLabel("Code from the email")

        messageView

        PlannitButton(title: busy ? "Checking…" : "Continue", variant: .primary, size: .lg,
                      fullWidth: true) {
            verify(address, purpose: purpose)
        }
        .disabled(busy || code.count < 6)
        .opacity(busy || code.count < 6 ? 0.5 : 1)

        Text("Can't find it? Check spam, or send a new one. Only the newest code works.")
            .textStyle(.caption, color: .textFaint)
            .multilineTextAlignment(.center)

        PlannitButton(title: "Send a new code", variant: .ghost, size: .md, fullWidth: true) {
            resend(address, purpose: purpose)
        }
        .disabled(busy)

        PlannitButton(title: "Use a different email", variant: .ghost, size: .md, fullWidth: true) {
            go(to: purpose == .signUp ? .form : .forgot)
        }
    }

    private func verify(_ address: String, purpose: SupabaseClient.CodePurpose) {
        switch purpose {
        case .signUp:
            run { await model.confirmSignUp(email: address, code: code) }
        case .passwordReset:
            busy = true
            message = nil
            Task { @MainActor in
                let problem = await model.verifyResetCode(email: address, code: code)
                busy = false
                if let problem { show(problem) } else { go(to: .newPassword) }
            }
        }
    }

    private func resend(_ address: String, purpose: SupabaseClient.CodePurpose) {
        busy = true
        message = nil
        Task { @MainActor in
            let problem = purpose == .signUp
                ? await model.resendSignUpCode(email: address)
                : await model.requestPasswordReset(email: address)
            busy = false
            if let problem { show(problem) } else { show("A new code is on its way.", isError: false) }
        }
    }

    // MARK: Password reset

    @ViewBuilder
    private var forgot: some View {
        emailField
        messageView
        PlannitButton(title: busy ? "Sending…" : "Send code", variant: .primary, size: .lg,
                      fullWidth: true) {
            let address = AppModel.clean(email)
            busy = true
            message = nil
            Task { @MainActor in
                let problem = await model.requestPasswordReset(email: address)
                busy = false
                if let problem { show(problem) } else { go(to: .resetCode(email: address)) }
            }
        }
        .disabled(busy || email.isEmpty)
        .opacity(busy || email.isEmpty ? 0.5 : 1)
        PlannitButton(title: "Back to sign in", variant: .ghost, size: .md, fullWidth: true) {
            go(to: .form)
        }
    }

    @ViewBuilder
    private var newPassword: some View {
        PasswordField(placeholder: "New password (\(PasswordRules.minimumLength)+ characters)",
                      text: $password, contentType: .newPassword)
        PasswordField(placeholder: "Confirm new password", text: $confirm,
                      contentType: .newPassword, invalid: mismatch)
        if mismatch { hint("The passwords don't match.") }
        messageView
        PlannitButton(title: busy ? "Saving…" : "Save and sign in", variant: .primary, size: .lg,
                      fullWidth: true) {
            run { await model.setNewPassword(password, confirm: confirm) }
        }
        .disabled(busy || password.isEmpty || confirm.isEmpty)
        .opacity(busy || password.isEmpty || confirm.isEmpty ? 0.5 : 1)
        PlannitButton(title: "Cancel", variant: .ghost, size: .md, fullWidth: true) {
            // The reset code already signed this device in; don't leave that behind.
            model.signOut()
            go(to: .form)
        }
    }

    // MARK: Pieces

    private var emailField: some View {
        PTextField(placeholder: "Email", text: $email, icon: "inbox")
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.emailAddress)
            .textContentType(.username)
    }

    @ViewBuilder
    private var messageView: some View {
        if let message {
            Text(message)
                .textStyle(.footnote, color: messageIsError ? .statusDanger : .statusFree)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text).textStyle(.footnote, color: .statusDanger)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func show(_ text: String, isError: Bool = true) {
        messageIsError = isError
        message = text
    }

    /// Move between steps. Codes and passwords never carry over — a code is for
    /// one email, and a half-typed password shouldn't reappear somewhere else.
    private func go(to next: Step) {
        message = nil
        code = ""
        if next == .newPassword || next == .form { password = ""; confirm = "" }
        step = next
    }

    /// Run an attempt and route on how it ended.
    private func run(_ attempt: @escaping () async -> AppModel.AuthOutcome,
                     onNeedsCode: @escaping () -> Void = {}) {
        busy = true
        message = nil
        Task { @MainActor in
            let outcome = await attempt()
            busy = false
            switch outcome {
            case .signedIn:         onSignedIn()
            case .needsCode:        onNeedsCode()
            case .cancelled:        break
            case .failed(let text): show(text)
            }
        }
    }
}
