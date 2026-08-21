import SwiftUI
import UIKit

// One of your own calendar's events, opened from the calendar list.
//
// Read-only on purpose. Plannit never writes to a calendar it didn't create
// (sync-contract, "A dedicated Plannit calendar"), so the honest thing to offer
// is a way through to the app that *does* own it rather than fields that would
// silently fail to save.
//
// Nothing here leaves the phone. The title and location are read straight from
// EventKit for this screen and are never uploaded — availability sends merged
// start/end ranges and nothing else (decision D-17).

struct DeviceEventDetail: View {
    let event: DeviceEvent
    @Environment(\.dismiss) private var dismiss

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
                    detailRow("lock", "Visibility", "Only you — Plannit shares free/busy, never this")
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, 8)

                PlannitButton(title: "Open in Calendar", variant: .secondary, size: .lg,
                              icon: "external-link", fullWidth: true) { openCalendarApp() }
                    .padding(.horizontal, Space.gutter)
                    .padding(.top, 20)

                HStack(alignment: .top, spacing: 8) {
                    PIcon("info", size: 16, color: .textFaint)
                    Text("Plannit doesn't edit your own calendars — only the plans it made. "
                         + "This event still counts towards when you're busy.")
                        .textStyle(.caption, color: .textMuted)
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, 12)

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
            }
            .padding(.horizontal, Space.gutter).padding(.vertical, 6)
            .background(.ultraThinMaterial)
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
