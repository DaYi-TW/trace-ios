import SwiftUI
import SwiftData

@main
struct TraceApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema(versionedSchema: TraceSchemaV2.self)
            modelContainer = try ModelContainer(
                for: schema,
                migrationPlan: TraceMigrationPlan.self
            )
        } catch {
            fatalError("Unable to create Trace model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}
