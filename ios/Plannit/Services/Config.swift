import Foundation

// Backend configuration. Reads Supabase creds from Info.plist; when empty the
// app runs in demo mode (sample data). Fill these in for live-backend testing:
//   SUPABASE_URL       https://<project-ref>.supabase.co
//   SUPABASE_ANON_KEY  <anon key from Settings → API>

enum Config {
    static var supabaseURL: String {
        (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? "")
            .trimmingCharacters(in: .whitespaces)
    }
    static var supabaseAnonKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespaces)
    }
    static var isLiveBackend: Bool {
        !supabaseURL.isEmpty && !supabaseAnonKey.isEmpty
    }
}
