import SwiftUI

// Groups tab — group cards, group detail (shared events + people), create sheet.
// Mirrors ui_kits/plannit-ios/GroupsScreen.jsx.

struct GroupsScreen: View {
    @State private var showNewGroup = false

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
                SectionLabel("Your groups") { Text("\(Sample.groups.count)").textStyle(.caption, color: .textFaint) }
                LazyVStack(spacing: Space.gapList) {
                    ForEach(Sample.groups) { group in
                        NavigationLink(value: group) {
                            GroupCard(name: group.name, note: group.note, hue: group.hue, members: group.members)
                        }
                        .buttonStyle(CardPressStyle())
                    }
                }
                .padding(.horizontal, Space.gutter)

                PlannitButton(title: "Make a group", variant: .secondary, size: .md,
                              icon: "plus", fullWidth: true) { showNewGroup = true }
                    .padding(.horizontal, Space.gutter)
                    .padding(.top, 16)

                Color.clear.frame(height: 120)
            }
        }
        .background(Color.appBg)
        .navigationBarHidden(true)
        .navigationDestination(for: PGroup.self) { GroupDetailView(group: $0) }
        .navigationDestination(for: PEvent.self) { EventDetailView(event: $0) }
        .sheet(isPresented: $showNewGroup) { NewGroupSheet() }
    }
}

struct GroupDetailView: View {
    let group: PGroup
    @Environment(\.dismiss) private var dismiss
    @State private var showNewPlan = false

    private var sharedEvents: [PEvent] { Sample.events.filter { $0.group == group.name } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(Color.white.opacity(0.25)).frame(width: 52, height: 52)
                        .overlay(PIcon("users", size: 26, color: .white, weight: .semibold))
                    Text(group.name).textStyle(.title1, color: .white)
                    Text(group.note).textStyle(.subhead, color: .white.opacity(0.9))
                    AvatarStack(names: group.members, size: 30, max: 6)
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

                SectionLabel("People")
                VStack(spacing: Space.gapInline) {
                    ForEach(Array(group.members.enumerated()), id: \.offset) { _, name in
                        HStack(spacing: 12) {
                            Avatar(name: name, size: 36)
                            Text(name).textStyle(.body, color: .textBody)
                            Spacer()
                        }
                        .padding(.horizontal, Space.gutter)
                    }
                }
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
                IconButton(icon: "user-plus", variant: .secondary, size: 40, iconSize: 18,
                           accessibilityLabel: "Add people") {}
            }
            .padding(.horizontal, Space.gutter)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $showNewPlan) { NewPlanSheet(preselected: group) { _, _ in showNewPlan = false } }
    }
}

struct NewGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var hue: GroupHue = .teal
    @State private var selected: Set<String> = []

    private let people = ["Maya Ellis", "Theo Sand", "Ada Kim", "Sam Roe", "Rae Loft", "Jo Vane"]

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "New group") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    field("Name") { PTextField(placeholder: "e.g. Soccer", text: $name, icon: "users") }
                    field("Colour") { HuePicker(selection: $hue) }
                    field("People") {
                        VStack(spacing: Space.gapInline) {
                            ForEach(people, id: \.self) { person in
                                Button { toggle(person) } label: {
                                    HStack(spacing: 12) {
                                        Avatar(name: person, size: 34)
                                        Text(person).textStyle(.body, color: .textStrong)
                                        Spacer()
                                        PIcon(selected.contains(person) ? "circle-check" : "circle",
                                              size: 22, color: selected.contains(person) ? .actionPrimary : .textFaint)
                                    }
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, 4)
            }
            PlannitButton(title: "Create group", variant: .primary, size: .lg, fullWidth: true) { dismiss() }
                .padding(Space.gutter)
                .disabled(name.isEmpty)
                .opacity(name.isEmpty ? 0.5 : 1)
        }
        .background(Color.appBg)
        .presentationDetents([.large])
    }

    private func field<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased()).textStyle(.overline, color: .textFaint)
            content()
        }
    }

    private func toggle(_ p: String) {
        withAnimation(Motion.fast) { _ = selected.contains(p) ? selected.remove(p) : selected.insert(p) }
    }
}
