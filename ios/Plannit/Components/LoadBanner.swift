import SwiftUI

// LoadBanner — says out loud when a live load failed, instead of leaving an
// empty screen that looks like "you have nothing".

struct LoadBanner: View {
    let message: String
    var retry: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            PIcon("circle-alert", size: 18, color: .statusWarning)
            Text(message).textStyle(.footnote, color: .textBody)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(action: retry) {
                Text("Retry").textStyle(.subhead, color: .actionPrimary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(GroupHue.amber.soft)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .padding(.horizontal, Space.gutter)
        .padding(.bottom, 4)
    }
}

extension Bundle {
    /// "0.1.0 (12)" for the You screen — the first thing you want in a bug report.
    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }
}
