import SwiftUI
import UIKit

// One of your own calendar's events, opened from the calendar list.
//
// Not editable on purpose. Plannit never writes to a calendar it didn't create
// (sync-contract, "A dedicated Plannit calendar"), so the honest thing to offer
// is a way through to the app that *does* own it rather than fields that would
// silently fail to save.
//
// Sharing is different from editing. Nothing on this screen leaves the phone
// until you tap "Share with a group" — availability sends merged start/end
// ranges and nothing else (D-17). That one tap copies this event's title, time
// and place to Plannit so the group can see it, which is the exception the API
// contract has always carried: raw events stay on the phone *unless explicitly
// shared*. The button says so.

struct DeviceEventDetail: View {
    let event: DeviceEvent
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var sharing = false
    @State private var shareTarget: PEvent?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 52, height: 52)
                        .overlay(PIcon("calendar", size: 26, color: .white, weight: .semibold))
                    Text(event.title).textStyle(.title1, color: .white)
                    Text("FROM YOUR CALENDAR").textStyle(.overline, color: .white.opacity(0.85))
                }
                .padding(Space.gutter)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(GroupHue.coral.color)

                VStack(spacing: 0) {
                    detailRow("clock", "When", when)
                    if let location = event.location, !location.isEmpty {
                        detailRow("map-pin", "Place", location)
                    }
                    detailRow(shared == nil ? "lock" : "users", "Visibility", visibility)
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, 8)

                PlannitButton(title: sharing ? "Sharing…" : shareTitle,
                              variant: .primary, size: .lg,
                              icon: "share-2", fullWidth: true) { share() }
                    .disabled(sharing)
                    .padding(.horizontal, Space.gutter)
                    .padding(.top, 20)

                Text(shared == nil
                     ? "Sharing copies the title, time and place to Plannit so the "
                       + "group can see it. Nothing else from your calendar is sent."
                     : "Your group can see this. Change who, or stop sharing, above.")
                    .textStyle(.caption, color: .textFaint)
                    .padding(.horizontal, Space.gutter)
                    .padding(.top, 8)

                PlannitButton(title: "Open in Calendar", variant: .secondary, size: .lg,
                              icon: "external-link", fullWidth: true) { openCalendarApp() }
                    .padding(.horizontal, Space.gutter)
                    .padding(.top, 12)

                HStack(alignment: .top, spacing: 8) {
                    PIcon("info", size: 16, color: .textFaint)
                    Text("Plannit doesn't edit your own calendars — only the plans it made. "
                         + "Edits you make in Calendar follow through to anyone you shared "
                         + "this with. It counts towards when you're busy either way.")
                        .textStyle(.caption, color: .textMuted)
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, 12)

                Color.clear.frame(height: 40)
            }
        }
        .background(Color.appBg)
        .navigationBarHidden(true)
        .sheet(item: $shareTarget) { target in
            ShareSheet(event: target).environmentObject(model)
        }
        .safeAreaInset(edge: .top) {
            HStack {
                IconButton(icon: "chevron-left", variant: .secondary, size: 40, iconSize: 18,
                           accessibilityLabel: "Back") { dismiss() }
                Spacer()
            }
            .padding(.horizontal, Space.gutter).padding(.vertical, 6)
            .background(.ultraThinMaterial)
        }
    }

    /// The Plannit copy of this event, once you've shared it.
    private var shared: PEvent? { model.sharedCopy(of: event) }

    private var shareTitle: String {
        shared == nil ? "Share with a group" : "Change who can see it"
    }

    /// "Only you", or the groups it reached.
    private var visibility: String {
        guard let shared else { return "Only you — Plannit shares free/busy, never this" }
        let names = shared.sharedGroupIds.compactMap { id in
            model.groups.first { $0.id == id }?.name
        }
        switch names.count {
        case 0:  return "Copied to Plannit, not shared with anyone yet"
        case 1:  return "Shared with \(names[0])"
        default: return "Shared with \(names[0]) + \(names.count - 1) more"
        }
    }

    /// Copy it into Plannit if it isn't there yet, then open the usual picker.
    private func share() {
        if let shared {
            shareTarget = shared
            return
        }
        sharing = true
        Task {
            shareTarget = await model.shareDeviceEvent(event)
            sharing = false
        }
    }

    /// "Saturday 16 August · 2:00 – 4:00 PM", or "· all day".
    private var when: String {
        let day = DateFormatter(); day.dateFormat = "EEEE d MMMM"
        guard !event.isAllDay else { return "\(day.string(from: event.start)) · all day" }
        let time = DateFormatter(); time.dateFormat = "h:mm a"
        return "\(day.string(from: event.start)) · \(time.string(from: event.start)) – "
             + "\(time.string(from: event.end))"
    }

    /// There's no public way to open a *specific* event in Calendar, so we open
    /// the day it's on — `calshow:` takes seconds since the reference date.
    private func openCalendarApp() {
        let seconds = Int(event.start.timeIntervalSinceReferenceDate)
        guard let url = URL(string: "calshow:\(seconds)") else { return }
        UIApplication.shared.open(url)
    }

    private func detailRow(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            PIcon(icon, size: 18, color: .textMuted)
            Text(label).textStyle(.subhead, color: .textMuted).frame(width: 76, alignment: .leading)
            Text(value).textStyle(.body, color: .textStrong)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.hairline).frame(height: 1) }
    }
}
