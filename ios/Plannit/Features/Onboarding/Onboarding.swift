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
    var onDone: () -> Void

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
                PlannitButton(title: "Connect calendar", variant: .primary, size: .lg,
                              icon: "calendar", fullWidth: true, action: onDone)
                PlannitButton(title: "Not now", variant: .ghost, size: .md,
                              fullWidth: true, action: onDone)
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, 8)
        }
    }
}
