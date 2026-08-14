import SwiftUI

// Sample data — mirrors design-system/ui_kits/plannit-ios/data.js so the UI is
// fully explorable before the Supabase wiring lands.

enum Sample {
    static let me = "You Concho"

    static let people = PMember.named(
        ["Maya Ellis", "Theo Sand", "Ada Kim", "Sam Roe", "Rae Loft", "Jo Vane"])

    static let groups: [PGroup] = [
        PGroup(id: "soccer", name: "Soccer", hue: .teal,
               members: PMember.named(["Maya Ellis", "Theo Sand", "Ada Kim", "Sam Roe", "Rae Loft", "Jo Vane"]),
               note: "Tuesday + weekend games"),
        PGroup(id: "family", name: "Family", hue: .amber,
               members: PMember.named(["Maya Ellis", "Ada Kim", "Rae Loft"]),
               note: "Birthdays and Sunday lunch"),
        PGroup(id: "work", name: "Work", hue: .sky,
               members: PMember.named(["Theo Sand", "Sam Roe", "Jo Vane", "Ada Kim"]),
               note: "Offsites only, nothing else"),
        PGroup(id: "flat", name: "Flatmates", hue: .indigo,
               members: PMember.named(["Sam Roe", "Rae Loft"]),
               note: "Bills, bins, film nights"),
    ]

    /// Demo events hang off today rather than a fixed month, so the sample
    /// calendar is always populated around the day you open it.
    static func date(inDays days: Int, at hour: Int, _ minute: Int = 0) -> Date {
        let cal = Calendar.current
        let day = cal.date(byAdding: .day, value: days, to: Date()) ?? Date()
        return cal.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    static let events: [PEvent] = [
        PEvent(id: "e1", start: date(inDays: 2, at: 14), title: "Five-a-side", time: "2:00–4:00 PM",
               location: "Hackney Marshes",
               group: "Soccer", hue: .teal, icon: "dumbbell",
               people: ["Maya Ellis", "Theo Sand", "Ada Kim", "Sam Roe", "Rae Loft", "Jo Vane"],
               badge: "Found", badgeTone: .free, source: .plannit),
        PEvent(id: "e2", start: date(inDays: 2, at: 19, 30), title: "Dinner with Ada", time: "7:30 PM",
               location: "Bermondsey",
               hue: .coral, icon: "utensils", badge: "Private", badgeTone: .neutral, source: .device),
        PEvent(id: "e3", start: date(inDays: 3, at: 13), title: "Mum's birthday lunch", time: "1:00 PM",
               location: "Hers",
               group: "Family", hue: .amber, icon: "cake",
               people: ["Maya Ellis", "Ada Kim", "Rae Loft"], source: .plannit),
        PEvent(id: "e4", start: date(inDays: 6, at: 20), title: "Film night", time: "8:00 PM",
               location: "The flat",
               group: "Flatmates", hue: .indigo, icon: "film",
               people: ["Sam Roe", "Rae Loft"], source: .plannit),
        PEvent(id: "e5", start: date(inDays: 9, at: 9, 15), title: "Dentist", time: "9:15 AM",
               hue: .coral, icon: "clock", badge: "Private", badgeTone: .neutral, source: .device),
    ]

    static let proposals: [PProposal] = [
        PProposal(id: "p1", title: "Five-a-side", group: groups[0],
                  constraint: "Sat, Sun · afternoon · 2 hours", status: "voting", votes: 4,
                  slots: [
                      PSlot(day: "SAT", date: 16, time: "2:00 – 4:00 PM", free: 6, best: true),
                      PSlot(day: "SUN", date: 17, time: "11:00 AM – 1:00 PM", free: 5),
                      PSlot(day: "SAT", date: 23, time: "3:00 – 5:00 PM", free: 5),
                  ],
                  availability: [
                      PAvailability(name: "Maya", blocks: [BusyRange(start: 9, end: 11)]),
                      PAvailability(name: "Theo", blocks: [BusyRange(start: 8, end: 9), BusyRange(start: 18, end: 21)]),
                      PAvailability(name: "Ada", blocks: [BusyRange(start: 13, end: 14)]),
                      PAvailability(name: "Sam", blocks: []),
                      PAvailability(name: "Rae", blocks: [BusyRange(start: 19, end: 22)]),
                      PAvailability(name: "Jo", blocks: [BusyRange(start: 8, end: 10)]),
                  ]),
        PProposal(id: "p2", title: "Someone's 30th", group: groups[1],
                  constraint: "Fri, Sat · evening · next 3 months", status: "found", votes: 3,
                  slots: [PSlot(day: "SAT", date: 6, time: "7:00 PM", free: 3, best: true)]),
    ]
}
