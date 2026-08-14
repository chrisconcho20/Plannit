import SwiftUI

// Plans tab — proposals awaiting votes, the plan detail (slots + who's-free),
// the New Plan (date-finder) flow, and the You screen.
// Mirrors ui_kits/plannit-ios/PlansScreen.jsx.

struct PlansScreen: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Plans").textStyle(.title1, color: .textStrong)
                Spacer()
                IconButton(icon: "inbox", variant: .secondary, size: 40, iconSize: 18,
                           accessibilityLabel: "Archive") {}
            }
            .padding(.horizontal, Space.gutter)
            .padding(.vertical, 6)

            ScrollView {
                SectionLabel("Awaiting your vote")
                LazyVStack(spacing: Space.gapList) {
                    ForEach(model.proposals) { proposal in
                        NavigationLink(value: proposal) { ProposalRow(proposal: proposal) }
                            .buttonStyle(CardPressStyle())
                    }
                }
                .padding(.horizontal, Space.gutter)

                EmptyState(icon: "sparkles", title: "Find a time",
                           message: "Tap ＋ to pick a group and let Plannit find when everyone’s free.")
                Color.clear.frame(height: 120)
            }
        }
        .background(Color.appBg)
        .navigationBarHidden(true)
        .navigationDestination(for: PProposal.self) { PlanDetailView(proposal: $0) }
    }
}

struct ProposalRow: View {
    let proposal: PProposal

    var body: some View {
        PlannitCard(elevation: 1) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(proposal.title).textStyle(.headline, color: .textStrong)
                    Spacer()
                    if proposal.status == "voting" {
                        Badge(text: "\(proposal.votes) voted", tone: .primary, icon: "thumbs-up")
                    } else {
                        Badge(text: "Found", tone: .free, icon: "check")
                    }
                }
                HStack(spacing: 6) {
                    Circle().fill(proposal.group.hue.color).frame(width: 7, height: 7)
                    Text(proposal.group.name).textStyle(.caption, color: .textMuted)
                    Text("·").foregroundStyle(Color.textFaint)
                    Text(proposal.constraint).textStyle(.caption, color: .textMuted)
                }
                if let best = proposal.slots.first {
                    HStack(spacing: 10) {
                        PIcon("calendar-check", size: 16, color: .statusFree)
                        Text("\(best.day) \(best.date) · \(best.time)").textStyle(.subhead, color: .textBody)
                        Spacer()
                        Badge(text: "\(best.free)/\(proposal.total) free", tone: best.free == proposal.total ? .free : .neutral)
                    }
                    .padding(.top, 2)
                }
            }
        }
    }
}

struct PlanDetailView: View {
    let proposal: PProposal
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSlot: UUID?
    @State private var locked = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(proposal.title).textStyle(.title1, color: .textStrong)
                        HStack(spacing: 6) {
                            Circle().fill(proposal.group.hue.color).frame(width: 8, height: 8)
                            Text(proposal.group.name).textStyle(.subhead, color: .textMuted)
                        }
                        Text(proposal.constraint).textStyle(.footnote, color: .textFaint)
                    }
                    .padding(.horizontal, Space.gutter)
                    .padding(.top, 4)

                    SectionLabel("Best times")
                    LazyVStack(spacing: Space.gapList) {
                        ForEach(proposal.slots) { slot in
                            Button { withAnimation(Motion.fast) { selectedSlot = slot.id } } label: {
                                SlotCard(day: slot.day, date: slot.date, time: slot.time,
                                         freeCount: slot.free, total: proposal.total,
                                         people: Array(proposal.group.memberNames.prefix(slot.free)),
                                         best: slot.best, selected: selectedSlot == slot.id)
                            }
                            .buttonStyle(CardPressStyle())
                        }
                    }
                    .padding(.horizontal, Space.gutter)

                    if !proposal.availability.isEmpty {
                        SectionLabel("Who's free") { Text("8am – 10pm").textStyle(.caption, color: .textFaint) }
                        PlannitCard(elevation: 1) {
                            VStack(spacing: 12) {
                                ForEach(proposal.availability) { person in
                                    AvailabilityBar(name: person.name, blocks: person.blocks)
                                }
                            }
                        }
                        .padding(.horizontal, Space.gutter)
                    }
                    Color.clear.frame(height: 120)
                }
            }

            PlannitButton(title: locked ? "Locked in" : "Lock in this time",
                          variant: .free, size: .lg, icon: locked ? "check" : "calendar-check",
                          fullWidth: true) {
                withAnimation(Motion.pop) { locked = true }
            }
            .padding(Space.gutter)
            .background(.ultraThinMaterial)
            .disabled(selectedSlot == nil && !locked)
            .opacity(selectedSlot == nil && !locked ? 0.5 : 1)
        }
        .background(Color.appBg)
        .navigationBarHidden(true)
        .safeAreaInset(edge: .top) {
            HStack {
                IconButton(icon: "chevron-left", variant: .secondary, size: 40, iconSize: 18,
                           accessibilityLabel: "Back") { dismiss() }
                Spacer()
            }
            .padding(.horizontal, Space.gutter).padding(.vertical, 6)
            .background(.ultraThinMaterial)
        }
        .overlay(alignment: .top) {
            if locked {
                Toast(text: "Locked in — everyone will get it on their calendar")
                    .padding(.horizontal, Space.gutter).padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear { selectedSlot = proposal.slots.first(where: { $0.best })?.id }
    }
}

struct YouScreen: View {
    @EnvironmentObject private var model: AppModel
    @State private var showRename = false
    @State private var twoWaySync = true
    @State private var shareAvailability = true
    @State private var pushDateFound = true
    @State private var pushInvites = true
    @AppStorage(SearchWindow.key) private var searchMonths = SearchWindow.defaultMonths

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("You").textStyle(.title1, color: .textStrong)
                Spacer()
                IconButton(icon: "settings", variant: .secondary, size: 40, iconSize: 18,
                           accessibilityLabel: "Settings") {}
            }
            .padding(.horizontal, Space.gutter).padding(.vertical, 6)

            ScrollView {
                HStack(spacing: 14) {
                    Avatar(name: model.displayName, size: 60)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.displayName).textStyle(.title3, color: .textStrong)
                        Text(model.userEmail ?? (model.isLiveBackend ? "Signed in" : "Demo mode"))
                            .textStyle(.footnote, color: .textMuted)
                    }
                    Spacer()
                    PlannitButton(title: "Edit", variant: .secondary, size: .sm) { showRename = true }
                }
                .padding(Space.gutter)

                SectionLabel("Profile")
                settingsCard { nameRow() }

                SectionLabel("Date finder")
                settingsCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            PIcon("wand-sparkles", size: 20, color: .textMuted).frame(width: 22)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("How far ahead to look").textStyle(.headline, color: .textStrong)
                                Text("Plannit holds out for a time the whole group can make — a longer window makes that more likely.")
                                    .textStyle(.caption, color: .textMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        SegmentedControl(options: SearchWindow.options, selection: $searchMonths) {
                            SearchWindow.label($0)
                        }
                        .padding(.leading, 34)
                    }
                    .padding(.vertical, 12)
                }

                SectionLabel("Calendar")
                settingsCard {
                    toggleRow("calendar-check", "Two-way sync", "Keep Plannit and your calendar in step", $twoWaySync)
                    divider
                    toggleRow("eye-off", "Share availability", "Only free/busy — never event details", $shareAvailability)
                }

                SectionLabel("Notifications")
                settingsCard {
                    toggleRow("wand-sparkles", "A date was found", "When Plannit finds a time for a group", $pushDateFound)
                    divider
                    toggleRow("user-plus", "Invites & requests", "Friend requests and shared events", $pushInvites)
                }

                PlannitButton(title: "Sign out", variant: .danger, size: .md, fullWidth: true) {}
                    .padding(.horizontal, Space.gutter).padding(.top, 16)
                Color.clear.frame(height: 120)
            }
        }
        .background(Color.appBg)
        .navigationBarHidden(true)
        .sheet(isPresented: $showRename) {
            DisplayNameSheet(current: model.displayName).environmentObject(model)
        }
    }

    private var divider: some View { Rectangle().fill(Color.hairline).frame(height: 1).padding(.leading, 46) }

    private func settingsCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .padding(.horizontal, Space.card)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Color.hairline, lineWidth: 1))
            .padding(.horizontal, Space.gutter)
    }

    private func nameRow() -> some View {
        Button { showRename = true } label: {
            HStack(spacing: 12) {
                PIcon("user", size: 20, color: .textMuted).frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Display name").textStyle(.headline, color: .textStrong)
                    Text("Everyone in your groups sees this")
                        .textStyle(.caption, color: .textMuted)
                }
                Spacer()
                Text(model.displayName).textStyle(.subhead, color: .textMuted)
                PIcon("chevron-right", size: 16, color: .textFaint)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggleRow(_ icon: String, _ title: String, _ subtitle: String, _ binding: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            PIcon(icon, size: 20, color: .textMuted).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).textStyle(.headline, color: .textStrong)
                Text(subtitle).textStyle(.caption, color: .textMuted)
            }
            Spacer()
            Toggle("", isOn: binding).labelsHidden().tint(.statusFree)
        }
        .padding(.vertical, 12)
    }
}

// Rename yourself. The name is written to `profiles.display_name`, which is what
// everyone in your groups sees — including the avatars on a found slot.
struct DisplayNameSheet: View {
    let current: String

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var saving = false
    @State private var errorText: String?

    init(current: String) {
        self.current = current
        _name = State(initialValue: current)
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Display name") { dismiss() }
            VStack(alignment: .leading, spacing: 14) {
                PTextField(placeholder: "Your name", text: $name, icon: "user")
                Text("This is how you appear to everyone in your groups.")
                    .textStyle(.footnote, color: .textMuted)
                if let errorText {
                    Text(errorText).textStyle(.footnote, color: .statusDanger)
                }
                PlannitButton(title: saving ? "Saving…" : "Save", variant: .primary,
                              size: .lg, fullWidth: true) { save() }
                    .disabled(saving || trimmed.isEmpty || trimmed == current)
                    .opacity(saving || trimmed.isEmpty || trimmed == current ? 0.5 : 1)
            }
            .padding(Space.gutter)
            Spacer(minLength: 0)
        }
        .background(Color.appBg)
        .presentationDetents([.height(280)])
    }

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func save() {
        saving = true
        errorText = nil
        Task {
            let ok = await model.updateDisplayName(trimmed)
            saving = false
            if ok { dismiss() } else { errorText = "Couldn’t save that name. Try again." }
        }
    }
}
