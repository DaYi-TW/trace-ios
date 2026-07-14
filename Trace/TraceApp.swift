import SwiftUI
import SwiftData

@main
struct TraceApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [TraceEvent.self, EvidenceAttachment.self])
    }
}
