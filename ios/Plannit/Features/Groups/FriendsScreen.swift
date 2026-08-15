import SwiftUI

// FriendsScreen — who you can plan with. Requests in, requests out, and adding
// someone by email.
//
// While the beta's `auto_friend_everyone` switch is on, every new account is
// friends with everyone automatically, so this list fills itself and the
// request flow is mostly dormant. The structure is real either way: turning the
// switch off (an UPDATE on app_config) leaves people adding each other by hand.

struct FriendsScreen: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var showAdd = false
    @State private var pendingRemoval: PMember?

    private var outgoing: [PFriendRequest] { model.friendRequests.filter { !$0.incoming } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !model.incomingRequests.isEmpty {
                    SectionLabel("Wants to be friends") {
                        Text("\(model.incomingRequests.count)")
                            .textStyle(.caption, color: .textFaint)
                    }
                    VStack(spacing: Space.gapList) {
                        ForEach(model.incomingRequests) { request in
                            requestRow(request)
                        }
                    }
                    .padding(.horizontal, Space.gutter)
                }

                SectionLabel("Friends") {
                    Text("\(model.friends.count)").textStyle(.caption, color: .textFaint)
                }
                if model.friends.isEmpty {
                    EmptyState(icon: "user-plus", title: "No friends yet",
                               message: "Add someone by the email they signed up with — or send a group invite link, which makes you friends automatically.",
                               actionTitle: "Add a friend") { showAdd = true }
                } else {
                    VStack(spacing: Space.gapInline) {
                        ForEach(model.friends) { friend in
                            HStack(spacing: 12) {
                                Avatar(name: friend.name, size: 38)
                                Text(friend.name).textStyle(.body, color: .textBody)
                                Spacer()
                                IconButton(icon: "x", variant: .ghost, size: 32, iconSize: 15,
                                           accessibilityLabel: "Remove \(friend.name)") {
                                    pendingRemoval = friend
                                }
                            }
                            .padding(.horizontal, Space.gutter)
                        }
                    }
                }

                if !outgoing.isEmpty {
                    SectionLabel("Asked")
                    VStack(spacing: Space.gapInline) {
                        ForEach(outgoing) { request in
                            HStack(spacing: 12) {
                                Avatar(name: request.person.name, size: 34)
                                Text(request.person.name).textStyle(.body, color: .textMuted)
                                Spacer()
                                Badge(text: "Waiting", tone: .neutral)
                            }
                            .padding(.horizontal, Space.gutter)
                        }
                    }
                }

                PlannitButton(title: "Add a friend", variant: .secondary, size: .md,
                              icon: "user-plus", fullWidth: true) { showAdd = true }
                    .padding(.horizontal, Space.gutter)
                    .padding(.top, 18)

                if model.autoFriendEveryone {
                    Text("Beta: everyone who joins Plannit is added as a friend automatically.")
                        .textStyle(.caption, color: .textFaint)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, Space.gutter)
                        .padding(.top, 10)
                }

                Color.clear.frame(height: 60)
            }
        }
        .background(Color.appBg)
        .navigationBarHidden(true)
        .safeAreaInset(edge: .top) {
            HStack {
                IconButton(icon: "chevron-left", variant: .secondary, size: 40, iconSize: 18,
                           accessibilityLabel: "Back") { dismiss() }
                Text("Friends").textStyle(.title3, color: .textStrong)
                Spacer()
            }
            .padding(.horizontal, Space.gutter)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $showAdd) { AddFriendSheet().environmentObject(model) }
        .confirmationDialog("Remove \(pendingRemoval?.name ?? "")?",
                            isPresented: Binding(get: { pendingRemoval != nil },
                                                 set: { if !$0 { pendingRemoval = nil } }),
                            titleVisibility: .visible) {
            if let person = pendingRemoval {
                Button("Remove friend", role: .destructive) {
                    Task { await model.removeFriend(person) }
                    pendingRemoval = nil
                }
            }
            Button("Cancel", role: .cancel) { pendingRemoval = nil }
        } message: {
            Text("They stay in any groups you share.")
        }
    }

    private func requestRow(_ request: PFriendRequest) -> some View {
        PlannitCard(elevation: 1) {
            HStack(spacing: 12) {
                Avatar(name: request.person.name, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(request.person.name).textStyle(.headline, color: .textStrong)
                    Text("Wants to plan with you").textStyle(.caption, color: .textMuted)
                }
                Spacer(minLength: 0)
                PlannitButton(title: "Accept", variant: .primary, size: .sm) {
                    Task { await model.respond(to: request, accept: true) }
                }
                IconButton(icon: "x", variant: .secondary, size: 34, iconSize: 15,
                           accessibilityLabel: "Decline") {
                    Task { await model.respond(to: request, accept: false) }
                }
            }
        }
    }
}

// Add someone by the email they signed up with. Exact match only — the lookup
// can't be used to browse who else is on Plannit.
struct AddFriendSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var searching = false
    @State private var found: PMember?
    @State private var message: String?

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Add a friend") { dismiss() }
            VStack(alignment: .leading, spacing: 14) {
                Text("THEIR EMAIL").textStyle(.overline, color: .textFaint)
                PTextField(placeholder: "name@example.com", text: $email, icon: "user")
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)

                if let found {
                    HStack(spacing: 12) {
                        Avatar(name: found.name, size: 38)
                        Text(found.name).textStyle(.headline, color: .textStrong)
                        Spacer()
                        PlannitButton(title: "Send request", variant: .primary, size: .sm) {
                            send(to: found)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if let message {
                    Text(message).textStyle(.footnote, color: .textMuted)
                }

                PlannitButton(title: searching ? "Looking…" : "Find them", variant: .secondary,
                              size: .lg, icon: "search", fullWidth: true) { lookUp() }
                    .disabled(searching || email.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(searching || email.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)

                Text("You need the exact address they signed up with — Plannit won't list who else is on it.")
                    .textStyle(.caption, color: .textFaint)
            }
            .padding(Space.gutter)
            Spacer(minLength: 0)
        }
        .background(Color.appBg)
        .presentationDetents([.height(420)])
    }

    private func lookUp() {
        searching = true
        message = nil
        found = nil
        Task {
            let person = await model.findPerson(email: email)
            searching = false
            found = person
            if person == nil {
                message = "No Plannit account with that email."
            } else if model.friends.contains(where: { $0.id == person?.id }) {
                found = nil
                message = "You're already friends."
            }
        }
    }

    private func send(to person: PMember) {
        Task {
            let ok = await model.sendFriendRequest(to: person)
            message = ok ? "Request sent to \(person.name)." : "Couldn't send that request."
            if ok { found = nil; email = "" }
        }
    }
}
