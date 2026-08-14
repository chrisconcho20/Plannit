import SwiftUI

// Groups tab — group cards, group detail (shared events + people), create sheet.
// Mirrors ui_kits/plannit-ios/GroupsScreen.jsx.

struct GroupsScreen: View {
    @EnvironmentObject private var model: AppModel
    @State private var showNewGroup = false
    @State private var pendingRemoval: PGroup?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Groups").textStyle(.title1, color: .textStrong)
                Spacer()
                IconButton(icon: "search", variant: .secondary, size: 40, iconSize: 18,
                           accessibilityLabel: "Search") {}
            }
            .padding(.horizontal, Space.gutter)
            .padding(.vertical, 6)

            ScrollView {
                if let error = model.loadError {
                    LoadBanner(message: error) { Task { await model.loadData() } }
                }
                SectionLabel("Your groups") { Text("\(model.groups.count)").textStyle(.caption, color: .textFaint) }
                LazyVStack(spacing: Space.gapList) {
                    ForEach(model.groups) { group in
                        let owned = group.isOwned(by: model.userId)
                        SwipeRow(title: owned ? "Delete" : "Leave",
                                 icon: owned ? "trash-2" : "x") {
                            pendingRemoval = group
                        } content: {
                            NavigationLink(value: group) {
                                GroupCard(name: group.name, note: group.note, hue: group.hue,
                                          members: group.memberNames)
                            }
                            .buttonStyle(CardPressStyle())
                        }
                    }
                }
                .padding(.horizontal, Space.gutter)

                PlannitButton(title: "Make a group", variant: .secondary, size: .md,
                              icon: "plus", fullWidth: true) { showNewGroup = true }
                    .padding(.horizontal, Space.gutter)
                    .padding(.top, 16)

                Color.clear.frame(height: 120)
            }
            .refreshable { await model.loadData() }
        }
        .background(Color.appBg)
        .navigationBarHidden(true)
        .navigationDestination(for: PGroup.self) { GroupDetailView(group: $0) }
        .navigationDestination(for: PEvent.self) { EventDetailView(event: $0) }
        .sheet(isPresented: $showNewGroup) { NewGroupSheet().environmentObject(model) }
        .confirmationDialog(
            pendingRemoval.map { $0.isOwned(by: model.userId)
                ? "Delete “\($0.name)”?" : "Leave “\($0.name)”?" } ?? "",
            isPresented: Binding(get: { pendingRemoval != nil },
                                 set: { if !$0 { pendingRemoval = nil } }),
            titleVisibility: .visible
        ) {
            if let group = pendingRemoval {
                let owned = group.isOwned(by: model.userId)
                Button(owned ? "Delete group" : "Leave group", role: .destructive) {
                    Task { _ = owned ? await model.deleteGroup(group) : await model.leaveGroup(group) }
                    pendingRemoval = nil
                }
            }
            Button("Cancel", role: .cancel) { pendingRemoval = nil }
        } message: {
            if let group = pendingRemoval, group.isOwned(by: model.userId) {
                Text("This removes the group for all \(group.members.count) people, along with its plans. It can't be undone.")
            }
        }
    }
}

struct GroupDetailView: View {
    let group: PGroup
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var showNewPlan = false
    @State private var showAddPeople = false
    @State private var pendingMember: PMember?
    @State private var confirmDeleteGroup = false

    /// Re-read from the model so the screen updates after add/remove.
    private var live: PGroup { model.groups.first { $0.id == group.id } ?? group }
    private var isOwner: Bool { live.isOwned(by: model.userId) }

    // Events actually shared with this group — matched by id, not by name.
    private var sharedEvents: [PEvent] {
        model.events.filter { $0.sharedGroupIds.contains(group.id) }
            .sorted { $0.start < $1.start }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(Color.white.opacity(0.25)).frame(width: 52, height: 52)
                        .overlay(PIcon("users", size: 26, color: .white, weight: .semibold))
                    Text(group.name).textStyle(.title1, color: .white)
                    Text(group.note).textStyle(.subhead, color: .white.opacity(0.9))
                    AvatarStack(names: live.memberNames, size: 30, max: 6)
                }
                .padding(Space.gutter)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(group.hue.color)

                PlannitButton(title: "Find a date for this group", variant: .free, size: .lg,
                              icon: "wand-sparkles", fullWidth: true) { showNewPlan = true }
                    .padding(.horizontal, Space.gutter)
                    .padding(.top, 16)

                SectionLabel("Shared events")
                if sharedEvents.isEmpty {
                    EmptyState(icon: "calendar", title: "No shared events yet",
                               message: "Events shared with \(group.name) show up here.")
                } else {
                    LazyVStack(spacing: Space.gapList) {
                        ForEach(sharedEvents) { event in
                            NavigationLink(value: event) {
                                EventCard(title: event.title, time: event.time, location: event.location,
                                          hue: event.hue, group: nil, people: event.people, icon: event.icon)
                            }
                            .buttonStyle(CardPressStyle())
                        }
                    }
                    .padding(.horizontal, Space.gutter)
                }

                SectionLabel("People") {
                    Text("\(live.members.count)").textStyle(.caption, color: .textFaint)
                }
                VStack(spacing: Space.gapInline) {
                    ForEach(live.members) { member in
                        HStack(spacing: 12) {
                            Avatar(name: member.name, size: 36)
                            Text(member.name).textStyle(.body, color: .textBody)
                            if member.id == live.ownerId { Badge(text: "Owner", tone: .neutral) }
                            Spacer()
                            // Only an owner can remove other people; anyone can
                            // remove themselves (that's leaving).
                            if isOwner && member.id != live.ownerId {
                                IconButton(icon: "x", variant: .ghost, size: 32, iconSize: 15,
                                           accessibilityLabel: "Remove \(member.name)") {
                                    pendingMember = member
                                }
                            }
                        }
                        .padding(.horizontal, Space.gutter)
                    }
                }

                if isOwner {
                    PlannitButton(title: "Add people", variant: .secondary, size: .md,
                                  icon: "user-plus", fullWidth: true) { showAddPeople = true }
                        .padding(.horizontal, Space.gutter)
                        .padding(.top, 12)
                }

                PlannitButton(title: isOwner ? "Delete group" : "Leave group",
                              variant: .danger, size: .md, icon: isOwner ? "trash-2" : "x",
                              fullWidth: true) { confirmDeleteGroup = true }
                    .padding(.horizontal, Space.gutter)
                    .padding(.top, 8)

                Color.clear.frame(height: 40)
            }
        }
        .background(Color.appBg)
        .navigationBarHidden(true)
        .safeAreaInset(edge: .top) {
            HStack {
                IconButton(icon: "chevron-left", variant: .secondary, size: 40, iconSize: 18,
                           accessibilityLabel: "Back") { dismiss() }
                Spacer()
                if isOwner {
                    IconButton(icon: "user-plus", variant: .secondary, size: 40, iconSize: 18,
                               accessibilityLabel: "Add people") { showAddPeople = true }
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
        }
        // Tell the shell which group is open, so the ＋ acts in this context.
        .onAppear { model.openGroup = live }
        .onDisappear { if model.openGroup?.id == group.id { model.openGroup = nil } }
        .sheet(isPresented: $showNewPlan) {
            NewPlanSheet(groups: model.groups, preselected: group) { _, _ in showNewPlan = false }
        }
        .sheet(isPresented: $showAddPeople) {
            AddPeopleSheet(group: live).environmentObject(model)
        }
        .confirmationDialog("Remove \(pendingMember?.name ?? "")?",
                            isPresented: Binding(get: { pendingMember != nil },
                                                 set: { if !$0 { pendingMember = nil } }),
                            titleVisibility: .visible) {
            if let member = pendingMember {
                Button("Remove from group", role: .destructive) {
                    Task { await model.removeMember(member, from: live) }
                    pendingMember = nil
                }
            }
            Button("Cancel", role: .cancel) { pendingMember = nil }
        }
        .confirmationDialog(isOwner ? "Delete “\(group.name)”?" : "Leave “\(group.name)”?",
                            isPresented: $confirmDeleteGroup, titleVisibility: .visible) {
            Button(isOwner ? "Delete group" : "Leave group", role: .destructive) {
                let target = live
                Task {
                    _ = isOwner ? await model.deleteGroup(target) : await model.leaveGroup(target)
                }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if isOwner {
                Text("This removes the group for all \(live.members.count) people, along with its plans. It can't be undone.")
            }
        }
    }
}

struct NewGroupSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var hue: GroupHue = .teal
    @State private var selected: Set<String> = []
    @State private var busy = false
    @State private var errorText: String?

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "New group") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    field("Name") { PTextField(placeholder: "e.g. Soccer", text: $name, icon: "users") }
                    field("Colour") { HuePicker(selection: $hue) }
                    field("People") {
                        PeoplePicker(people: model.people, selected: $selected)
                    }
                    if let errorText {
                        Text(errorText).textStyle(.footnote, color: .statusDanger)
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, 4)
            }
            PlannitButton(title: busy ? "Creating…" : "Create group", variant: .primary, size: .lg,
                          fullWidth: true) { create() }
                .padding(Space.gutter)
                .disabled(name.isEmpty || busy)
                .opacity(name.isEmpty || busy ? 0.5 : 1)
        }
        .background(Color.appBg)
        .presentationDetents([.large])
    }

    private func create() {
        busy = true
        errorText = nil
        Task {
            let members = model.people.filter { selected.contains($0.id) }
            let ok = await model.createGroup(name: name, members: members)
            busy = false
            if ok { dismiss() } else { errorText = "Couldn’t create that group. Try again." }
        }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased()).textStyle(.overline, color: .textFaint)
            content()
        }
    }
}

// Add people to a group that already exists.
struct AddPeopleSheet: View {
    let group: PGroup

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []
    @State private var busy = false
    @State private var errorText: String?

    /// Everyone you know who isn't in this group yet.
    private var candidates: [PMember] {
        let existing = Set(group.members.map(\.id))
        return model.people.filter { !existing.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Add to \(group.name)") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if candidates.isEmpty {
                        EmptyState(icon: "user-plus", title: "Nobody left to add",
                                   message: "Everyone you know is already in this group. Friend requests are coming — for now you can only add people you already share a group with.")
                    } else {
                        PeoplePicker(people: candidates, selected: $selected)
                    }
                    if let errorText {
                        Text(errorText).textStyle(.footnote, color: .statusDanger)
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, 4)
            }
            PlannitButton(title: busy ? "Adding…" : "Add \(selected.count) \(selected.count == 1 ? "person" : "people")",
                          variant: .primary, size: .lg, icon: "user-plus", fullWidth: true) { add() }
                .padding(Space.gutter)
                .disabled(selected.isEmpty || busy)
                .opacity(selected.isEmpty || busy ? 0.5 : 1)
        }
        .background(Color.appBg)
        .presentationDetents([.large])
    }

    private func add() {
        busy = true
        errorText = nil
        Task {
            let members = candidates.filter { selected.contains($0.id) }
            let ok = await model.addMembers(to: group, members: members)
            busy = false
            if ok { dismiss() } else { errorText = "Couldn’t add them. Only the group's owner can." }
        }
    }
}

// The shared people list. Selection is by profile id, not name, so two people
// called Sam don't collide.
struct PeoplePicker: View {
    let people: [PMember]
    @Binding var selected: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: Space.gapInline) {
            if people.isEmpty {
                Text("Nobody to add yet. People you share a group with show up here.")
                    .textStyle(.footnote, color: .textMuted)
            }
            ForEach(people) { person in
                Button { toggle(person.id) } label: {
                    HStack(spacing: 12) {
                        Avatar(name: person.name, size: 34)
                        Text(person.name).textStyle(.body, color: .textStrong)
                        Spacer()
                        PIcon(selected.contains(person.id) ? "circle-check" : "circle",
                              size: 22, color: selected.contains(person.id) ? .actionPrimary : .textFaint)
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggle(_ id: String) {
        withAnimation(Motion.fast) {
            if selected.contains(id) { _ = selected.remove(id) } else { _ = selected.insert(id) }
        }
    }
}
