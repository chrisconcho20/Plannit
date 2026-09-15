import SwiftUI

// DeleteAccountSheet — leaving Plannit for good.
//
// Says exactly what goes and what happens to other people's groups before
// anything is touched, and asks for the word DELETE rather than a second tap:
// there is no undo, and a stray tap on a confirmation dialog is easy.

struct DeleteAccountSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var typed = ""
    @State private var deleting = false
    @State private var errorText: String?

    private let confirmWord = "DELETE"
    private var confirmed: Bool { typed.trimmingCharacters(in: .whitespaces).uppercased() == confirmWord }

    private var ownedGroupsWithOthers: [PGroup] {
        model.groups.filter { $0.ownerId == model.userId && $0.members.count > 1 }
    }
    private var ownedSoloGroups: [PGroup] {
        model.groups.filter { $0.ownerId == model.userId && $0.members.count <= 1 }
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Delete account") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("This permanently deletes your Plannit account. It can't be undone.")
                        .textStyle(.headline, color: .statusDanger)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("WHAT'S DELETED").textStyle(.overline, color: .textFaint)
                        bullet("Your profile, username, friend code and photo")
                        bullet("Your friends and friend requests")
                        bullet("Your availability and your answers to plans")
                        bullet("Every event and plan you created — removed from everyone's calendars")
                        bullet("Plannit's copies of plans in this phone's calendar")
                    }

                    if !ownedGroupsWithOthers.isEmpty || !ownedSoloGroups.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("YOUR GROUPS").textStyle(.overline, color: .textFaint)
                            if !ownedGroupsWithOthers.isEmpty {
                                bullet("\(names(ownedGroupsWithOthers)) will pass to the member who has been in \(ownedGroupsWithOthers.count == 1 ? "it" : "each") longest.")
                            }
                            if !ownedSoloGroups.isEmpty {
                                bullet("\(names(ownedSoloGroups)) will be deleted — nobody else is in \(ownedSoloGroups.count == 1 ? "it" : "them").")
                            }
                        }
                    }

                    Text("Events stay in your own device calendar — Plannit never deletes those.")
                        .textStyle(.footnote, color: .textMuted)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("TYPE \(confirmWord) TO CONFIRM").textStyle(.overline, color: .textFaint)
                        PTextField(placeholder: confirmWord, text: $typed, icon: "trash-2")
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                    }

                    if let errorText {
                        Text(errorText).textStyle(.footnote, color: .statusDanger)
                    }
                }
                .padding(Space.gutter)
            }
            PlannitButton(title: deleting ? "Deleting…" : "Delete my account", variant: .danger,
                          size: .lg, fullWidth: true) {
                delete()
            }
            .disabled(!confirmed || deleting)
            .opacity(!confirmed || deleting ? 0.5 : 1)
            .padding(Space.gutter)
        }
        .background(Color.appBg)
        .presentationDetents([.large])
        .interactiveDismissDisabled(deleting)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•").textStyle(.body, color: .textMuted)
            Text(text).textStyle(.body, color: .textBody)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func names(_ groups: [PGroup]) -> String {
        let list = groups.map(\.name)
        switch list.count {
        case 1:  return list[0]
        case 2:  return "\(list[0]) and \(list[1])"
        default: return "\(list.dropLast().joined(separator: ", ")) and \(list.last!)"
        }
    }

    private func delete() {
        deleting = true
        errorText = nil
        Task { @MainActor in
            if let problem = await model.deleteAccount() {
                deleting = false
                errorText = problem
            }
            // On success the model signs out and the app returns to the front door.
        }
    }
}
