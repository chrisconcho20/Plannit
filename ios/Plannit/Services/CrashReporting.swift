import Foundation
import Sentry

// CrashReporting — crashes and hangs, sent to Sentry, and nothing more.
//
// Off unless SENTRY_DSN is set in Info.plist, which the repo keeps empty and a
// release build fills in at build time (like the Supabase keys), and off in
// DEBUG builds so development crashes don't reach the project.
//
// Everything that could carry user content is switched off: no screenshots, no
// view hierarchy (it contains on-screen text — event titles, names), no network
// breadcrumbs or failed-request capture (PostgREST URLs carry ids and filters),
// no performance tracing, no default PII. What's left is a stack trace, the
// device model and OS, the app version, and whether the session crashed. That
// is what the App Store privacy label has to declare as "Crash Data".

enum CrashReporting {
    static var dsn: String {
        (Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String ?? "")
            .trimmingCharacters(in: .whitespaces)
    }

    static var isEnabled: Bool {
        #if DEBUG
        return false
        #else
        return !dsn.isEmpty
        #endif
    }

    static func start() {
        guard isEnabled else { return }
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"

        SentrySDK.start { options in
            options.dsn = dsn
            options.releaseName = "plannit@\(version)+\(build)"
            options.environment = Config.isLiveBackend ? "production" : "demo"

            options.sendDefaultPii = false
            options.attachScreenshot = false
            options.attachViewHierarchy = false
            options.enableNetworkTracking = false
            options.enableNetworkBreadcrumbs = false
            options.enableCaptureFailedRequests = false
            options.enableAutoPerformanceTracing = false
            options.enableUserInteractionTracing = false
            options.tracesSampleRate = 0
            options.maxBreadcrumbs = 30

            // Belt and braces: nothing in Plannit sets a Sentry user or request,
            // and an event that somehow carries one leaves without it.
            options.beforeSend = { event in
                event.user = nil
                event.request = nil
                return event
            }
        }
    }
}
