import SwiftUI

// App-wide state. In demo mode (no Supabase config) the app runs entirely on
// sample data; connecting the calendar adds real device events on top.

@MainActor
final class AppModel: ObservableObject {
    @Published var calendarConnected = false
    @Published var calendarDenied = false
    @Published var deviceEvents: [DeviceEvent] = []

    private let calendar = CalendarService()

    var isLiveBackend: Bool { Config.isLiveBackend }

    func connectCalendar() async {
        let granted = await calendar.requestAccess()
        calendarConnected = granted
        calendarDenied = !granted
        if granted { deviceEvents = calendar.fetchDeviceEvents() }
    }

    func refreshCalendar() {
        guard calendarConnected else { return }
        deviceEvents = calendar.fetchDeviceEvents()
    }
}
