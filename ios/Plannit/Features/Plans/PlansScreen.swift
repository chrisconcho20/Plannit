import SwiftUI

// Plans tab — proposals awaiting votes, the plan detail (slots + who's-free),
// the New Plan (date-finder) flow, and the You screen.
// Mirrors ui_kits/plannit-ios/PlansScreen.jsx.

struct PlansScreen: View {
    @EnvironmentObject private var model: AppModel

    private var open: [PProposal] { model.proposals.filter { !$0.isFinalized } }
    private var settled: [PProposal] { model.proposals.filter(\.isFinalized) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Plans").textStyle(.title1, color: .textStrong)
                Spacer()
            }
            .padding(.horizontal, Space.gutter)
            .padding(.vertical, 6)

            ScrollView {
                if let error = model.loadError {
                    LoadBanner(message: error) { Task { await model.loadData() } }
                }
                if !open.isEmpty {
                    SectionLabel("Awaiting your vote") {
                        Text("\(open.count)").textStyle(.caption, color: .textFaint)
                    }
                    LazyVStack(spacing: Space.gapList) {
                        ForEach(open) { proposal in
                            NavigationLink(value: proposal) { ProposalRow(proposal: proposal) }
                                .buttonStyle(CardPressStyle())
                        }
                    }
                    .padding(.horizontal, Space.gutter)
                }

                if !settled.isEmpty {
                    SectionLabel("Locked in")
                    LazyVStack(spacing: Space.gapList) {
                        ForEach(settled) { proposal in
                            NavigationLink(value: proposal) { ProposalRow(proposal: proposal) }
                                .buttonStyle(CardPressStyle())
                        }
                    }
                    .padding(.horizontal, Space.gutter)
                }

                if model.proposals.isEmpty {
                    EmptyState(icon: "sparkles", title: "No plans yet",
                               message: "Tap ＋ to pick a group and let Plannit find when everyone’s free.")
                }
                Color.clear.frame(height: 120)
            }
            .refreshable { await model.loadData() }
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
                // Once a time is locked in, that's the one to show.
                let headline = proposal.slots.first { $0.id == proposal.finalizedSlotId }
                    ?? proposal.slots.first
                if let best = headline {
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
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSlot: String?
    @State private var busy = false
    @State private var toast: String?

    /// Re-read from the model so votes and the lock-in land without a reopen.
    private var live: PProposal { model.proposals.first { $0.id == proposal.id } ?? proposal }
    private var canFinalize: Bool { live.canFinalize(model.userId) }
    private var chosen: PSlot? { live.slots.first { $0.id == selectedSlot } }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(live.title).textStyle(.title1, color: .textStrong)
                        HStack(spacing: 6) {
                            Circle().fill(live.group.hue.color).frame(width: 8, height: 8)
                            Text(live.group.name).textStyle(.subhead, color: .textMuted)
                        }
                        Text(live.constraint).textStyle(.footnote, color: .textFaint)
                        if live.isFinalized {
                            Badge(text: "Locked in", tone: .free, icon: "calendar-check")
                        }
                    }
                    .padding(.horizontal, Space.gutter)
                    .padding(.top, 4)

                    SectionLabel(live.isFinalized ? "The time" : "Best times") {
                        if !live.isFinalized {
                            Text("\(live.votes) of \(live.total) voted")
                                .textStyle(.caption, color: .textFaint)
                        }
                    }
                    LazyVStack(spacing: Space.gapList) {
                        ForEach(live.slots) { slot in
                            let mine = live.myVoteSlotId == slot.id
                            let count = live.voteCounts[slot.id] ?? 0
                            Button { withAnimation(Motion.fast) { selectedSlot = slot.id } } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    SlotCard(day: slot.day, date: slot.date, time: slot.time,
                                             freeCount: slot.free, total: live.total,
                                             people: live.people(for: slot),
                                             best: slot.best,
                                             selected: selectedSlot == slot.id)
                                    if mine || count > 0 {
                                        HStack(spacing: 6) {
                                            if mine {
                                                Badge(text: "Your pick", tone: .primary, icon: "check")
                                            }
                                            if count > 0 {
                                                Text("\(count) vote\(count == 1 ? "" : "s")")
                                                    .textStyle(.caption, color: .textMuted)
                                            }
                                        }
                                        .padding(.leading, 4)
                                    }
                                }
                            }
                            .buttonStyle(CardPressStyle())
                            .opacity(live.isFinalized && live.finalizedSlotId != slot.id ? 0.45 : 1)
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

            footer
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
            if let toast {
                Toast(text: toast)
                    .padding(.horizontal, Space.gutter).padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            // Open on your vote if you've cast one, else the locked time, else the best.
            selectedSlot = live.myVoteSlotId ?? live.finalizedSlotId
                ?? live.slots.first(where: { $0.best })?.id
        }
    }

    // Vote first; locking a time in is the organiser's call and comes second.
    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 8) {
            if live.isFinalized {
                HStack(spacing: 8) {
                    PIcon("calendar-check", size: 18, color: .statusFree)
                    Text("Locked in — it's on everyone's calendar")
                        .textStyle(.subhead, color: .textBody)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                PlannitButton(title: voteTitle, variant: .primary, size: .lg,
                              icon: live.myVoteSlotId == selectedSlot ? "check" : "thumbs-up",
                              fullWidth: true) { castVote() }
                    .disabled(voteDisabled)
                    .opacity(voteDisabled ? 0.5 : 1)

                if canFinalize {
                    PlannitButton(title: busy ? "Locking in…" : "Lock in this time",
                                  variant: .free, size: .md, icon: "calendar-check",
                                  fullWidth: true) { lockIn() }
                        .disabled(chosen == nil || busy)
                        .opacity(chosen == nil || busy ? 0.5 : 1)
                }
            }
        }
        .padding(Space.gutter)
        .background(.ultraThinMaterial)
    }

    private var voteTitle: String {
        if busy { return "Saving…" }
        if live.myVoteSlotId == selectedSlot { return "Your pick" }
        return live.myVoteSlotId == nil ? "Vote for this time" : "Change my vote"
    }
    private var voteDisabled: Bool {
        chosen == nil || busy || live.myVoteSlotId == selectedSlot
    }

    private func castVote() {
        guard let slot = chosen else { return }
        busy = true
        Task {
            let ok = await model.vote(for: slot, on: live)
            busy = false
            show(ok ? "Voted — \(slot.day) \(slot.date), \(slot.time)"
                    : "Couldn't save your vote. Try again.")
        }
    }

    private func lockIn() {
        guard let slot = chosen else { return }
        busy = true
        Task {
            let ok = await model.lockIn(slot: slot, on: live)
            busy = false
            show(ok ? "Locked in — everyone will get it on their calendar"
                    : "Couldn't lock that in. Try again.")
        }
    }

    private func show(_ message: String) {
        withAnimation(Motion.base) { toast = message }
        Task {
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            withAnimation(Motion.base) { toast = nil }
        }
    }
}

struct YouScreen: View {
    @EnvironmentObject private var model: AppModel
    @State private var showRename = false
    @State private var confirmSignOut = false
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

                PlannitButton(title: "Sign out", variant: .danger, size: .md, fullWidth: true) {
                    confirmSignOut = true
                }
                .padding(.horizontal, Space.gutter).padding(.top, 16)

                Text("Plannit \(Bundle.appVersion)")
                    .textStyle(.caption, color: .textFaint)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                Color.clear.frame(height: 120)
            }
        }
        .background(Color.appBg)
        .navigationBarHidden(true)
        .sheet(isPresented: $showRename) {
            DisplayNameSheet(current: model.displayName).environmentObject(model)
        }
        .confirmationDialog("Sign out?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { model.signOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need your email and password to get back in.")
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
