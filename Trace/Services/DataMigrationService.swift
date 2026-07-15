import SwiftData

@MainActor
enum DataMigrationService {
    static func backfillOriginalRevisions(in modelContext: ModelContext) throws -> Int {
        let events = try modelContext.fetch(FetchDescriptor<TraceEvent>())
        var insertedCount = 0

        for event in events where event.revisions.isEmpty {
            let revision = EventRevision(
                event: event,
                source: .original,
                context: event.context,
                narrative: event.narrative,
                workImpact: event.workImpact
            )
            event.currentRevisionID = revision.id
            event.revisions.append(revision)
            modelContext.insert(revision)
            insertedCount += 1
        }

        if insertedCount > 0 {
            try modelContext.save()
        }
        return insertedCount
    }
}
