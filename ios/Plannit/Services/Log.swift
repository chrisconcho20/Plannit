import Foundation
import os

// Log — debug-build diagnostics for the things you can only test on a device.
//
// The app deliberately logs nothing in release: event titles, emails and tokens
// must never reach the console, and a security review confirmed none do. This
// keeps that true two ways — it compiles to nothing outside DEBUG, and it only
// ever takes counts and states, never user content. If you find yourself
// wanting to log a title to debug something, log the count instead.
//
// Watch it in Xcode's console while the app runs on your phone, or in
// Console.app filtered to subsystem `com.plannit.app`.

enum Log {
    #if DEBUG
    private static let calendar = Logger(subsystem: "com.plannit.app", category: "calendar")
    private static let sync = Logger(subsystem: "com.plannit.app", category: "sync")
    #endif

    /// EventKit: access, reads, and what we wrote back.
    static func cal(_ message: String) {
        #if DEBUG
        calendar.notice("\(message, privacy: .public)")
        #endif
    }

    /// Data loading, availability upload, realtime.
    static func sync(_ message: String) {
        #if DEBUG
        Self.sync.notice("\(message, privacy: .public)")
        #endif
    }
}
