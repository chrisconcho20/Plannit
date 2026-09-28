import SwiftUI

// QuietPlanRulesSheet — when a quiet plan of yours is allowed to become a plan.
//
// The rules are yours and they gate your own participation: how many people it
// takes before you're pulled in, and optionally the only people you want to be
// matched with. Nobody else's settings can lower your bar, which is why these
// live on the server — the matcher reads them, and a rule the server can't see
// is a rule that doesn't hold.
//
// A group can override the default, because "a five-a-side needs ten and a
// coffee needs one other person" is the ordinary case rather than the exotic one.

struct QuietPlanRulesSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    /// Nil is the default that applies to every group.
    @State private var scope: PGroup?
    @State private var minPeople = 3
    @State private var onlyWith: Set<String> = []
    @State private var loading = true
    @State private var saving = false

    private var scopeId: String { scope?.id ?? AppModel.everyGroupId }
    private var members: [PMember] { scope?.members ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Quiet plans") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("These decide when one of your quiet plans can turn into a real one. They only ever apply to you.")
                        .textStyle(.footnote, color: .textMuted)
                        .fixedSize(horizontal: false, vertical: true)

                    fieldLabel("These rules apply to")
                    Menu {
                        Button("Every group") { scope = nil }
                        ForEach(model.groups) { g in
                            Button(g.name) { scope = g }
                        }
                    } label: {
                        pickerRow(icon: "users", text: scope?.name ?? "Every group")
                    }

                    fieldLabel("It takes at least")
                    SegmentedControl(options: [2, 3, 4, 5], selection: $minPeople) { count in
                        count == 5 ? "5+" : "\(count)"
                    }
                    Text(minPeople == 2
                         ? "One other person is enough."
                         : "\(minPeople) people, including you, before anyone is told.")
                        .textStyle(.caption, color: .textMuted)

                    if scope != nil {
                        fieldLabel("Only match me with")
                        if members.isEmpty {
                            Text("Nobody else is in this group yet.")
                                .textStyle(.footnote, color: .textMuted)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(members) { member in
                                    memberRow(member)
                                    if member.id != members.last?.id {
                                        Divider().overlay(Color.hairline).padding(.leading, 46)
                                    }
                                }
                            }
                            .padding(.horizontal, Space.card)
                            .background(Color.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                            Text(onlyWith.isEmpty
                                 ? "Anyone in the group. Tick people to narrow it."
                                 : "Only matches where everyone else is someone you ticked.")
                                .textStyle(.caption, color: .textMuted)
                        }
                    } else {
                        Text("Pick a group above to choose who you'll be matched with in it.")
                            .textStyle(.caption, color: .textMuted)
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, 4)
                .padding(.bottom, 24)
                .opacity(loading ? 0.4 : 1)
            }

            VStack(spacing: 0) {
                Divider().overlay(Color.hairline)
                PlannitButton(title: saving ? "Saving…" : "Save", variant: .primary,
                              size: .lg, icon: "check", fullWidth: true) {
                    save()
                }
                .disabled(saving || loading)
                .opacity(saving || loading ? 0.5 : 1)
                .padding(Space.gutter)
            }
            .barSurface()
        }
        .background(Color.appBg)
        .presentationDetents([.large])
        .task { await load() }
        // Each scope has its own stored rule, so switching reloads rather than
        // carrying the last one's numbers across.
        .onChange(of: scope?.id) { _, _ in Task { await load() } }
    }

    private func memberRow(_ member: PMember) -> some View {
        Button {
            if onlyWith.contains(member.id) { onlyWith.remove(member.id) }
            else { onlyWith.insert(member.id) }
        } label: {
            HStack(spacing: 12) {
                Avatar(name: member.name, size: 34, hue: member.hue, imageURL: member.avatarURL)
                Text(member.name).textStyle(.body, color: .textStrong)
                Spacer()
                PIcon(onlyWith.contains(member.id) ? "circle-check" : "circle", size: 22,
                      color: onlyWith.contains(member.id) ? .actionPrimary : .textFaint)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func pickerRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            PIcon(icon, size: 18, color: .textFaint)
            Text(text).textStyle(.body, color: .textStrong)
            Spacer()
            PIcon("chevron-down", size: 16, color: .textFaint)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
            .strokeBorder(Color.lineStrong, lineWidth: 1))
    }

    private func load() async {
        loading = true
        let rule = await model.quietPlanRule(groupId: scopeId)
        minPeople = min(max(rule.minPeople, 2), 5)
        onlyWith = Set(rule.onlyWith)
        loading = false
    }

    private func save() {
        saving = true
        Task {
            let ok = await model.saveQuietPlanRule(groupId: scopeId, minPeople: minPeople,
                                                   onlyWith: Array(onlyWith))
            saving = false
            if ok { dismiss() }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased()).textStyle(.overline, color: .textFaint)
    }
}
