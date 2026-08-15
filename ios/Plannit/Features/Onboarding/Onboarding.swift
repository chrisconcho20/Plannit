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
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, 8)
        }
    }
}

// Email sign-in and sign-up. This is the only real way into a live build
// (Sign in with Apple needs a paid Apple Developer account), so it has to be
// able to *create* an account — otherwise every tester needs a row made for
// them by hand in the Supabase dashboard.

struct LiveSignInView: View {
    var onSignedIn: () -> Void
    @EnvironmentObject private var model: AppModel

    @State private var creating = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var message: String?
    @State private var messageIsError = true

    private var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty && (!creating || !name.isEmpty)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 12) {
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .fill(Color.actionPrimary).frame(width: 72, height: 72)
                    .overlay(PIcon("calendar-heart", size: 36, color: .white, weight: .bold))
                    .primaryGlow()
                Text("Plannit").textStyle(.display, color: .textStrong)
                Text(creating ? "Make plans that actually happen."
                              : "Welcome back.")
                    .textStyle(.subhead, color: .textMuted)
            }
            Spacer()

            VStack(spacing: 12) {
                SegmentedControl(options: [false, true], selection: $creating.animation(Motion.fast)) {
                    $0 ? "Create account" : "Sign in"
                }
                .padding(.bottom, 2)

                if creating {
                    PTextField(placeholder: "Your name", text: $name, icon: "user")
                        .textContentType(.name)
                }
                PTextField(placeholder: "Email", text: $email, icon: "inbox")
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                secureField

                if let message {
                    Text(message)
                        .textStyle(.footnote, color: messageIsError ? .statusDanger : .statusFree)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                PlannitButton(title: buttonTitle, variant: .primary, size: .lg,
                              fullWidth: true) { submit() }
                    .disabled(busy || !canSubmit)
                    .opacity(busy || !canSubmit ? 0.5 : 1)

                if creating {
                    Text("Your name is what your groups see. You can change it later.")
                        .textStyle(.caption, color: .textFaint)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, Space.gutter)
            Spacer()
        }
    }

    private var buttonTitle: String {
        if busy { return creating ? "Creating…" : "Signing in…" }
        return creating ? "Create account" : "Sign in"
    }

    private var secureField: some View {
        HStack(spacing: 10) {
            PIcon("lock", size: 18, color: .textFaint)
            SecureField(creating ? "Password (6+ characters)" : "Password", text: $password)
                .textStyle(.body, color: .textStrong)
                .textContentType(creating ? .newPassword : .password)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
            .strokeBorder(Color.lineStrong, lineWidth: 1))
    }

    private func submit() {
        busy = true
        message = nil
        Task { @MainActor in
            if creating {
                let problem = await model.signUp(email: email, password: password, name: name)
                busy = false
                if problem == nil {
                    onSignedIn()
                } else {
                    // "Check your inbox" isn't a failure, so don't paint it red.
                    messageIsError = !(problem!.hasPrefix("Check "))
                    message = problem
                    if !messageIsError { creating = false }
                }
            } else {
                let ok = await model.signInWithEmail(email, password)
                busy = false
                if ok {
                    onSignedIn()
                } else {
                    messageIsError = true
                    message = "Couldn't sign in. Check the email and password."
                }
            }
        }
    }
}
