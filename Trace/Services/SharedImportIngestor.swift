import Foundation
import SwiftData

@MainActor
enum SharedImportIngestor {
    static func ingestPendingBatches(into modelContext: ModelContext) throws -> Int {
        let batches = try SharedImportStore.pendingBatches()
        var importedCount = 0

        for (batch, directory) in batches {
            let event = TraceEvent(
                title: "待整理的聊天截圖",
                occurredAt: batch.createdAt,
                narrative: "此事件由 iOS 分享選單建立。請確認對話日期、人物、順序及與工作事件的關聯。"
            )
            let revision = EventRevision(
                event: event,
                source: .original,
                narrative: event.narrative
            )
            event.currentRevisionID = revision.id
            event.revisions.append(revision)
            modelContext.insert(event)
            modelContext.insert(revision)

            for item in batch.items {
                let sourceURL = directory.appendingPathComponent(item.storedFileName)
                let data = try Data(contentsOf: sourceURL)
                let attachment = try EvidenceStore.store(
                    data: data,
                    preferredFileName: item.originalFileName,
                    kind: .image
                )
                attachment.sourceDescription = item.sourceDescription
                attachment.event = event
                modelContext.insert(attachment)
                importedCount += 1
            }
            try SharedImportStore.remove(batchDirectory: directory)
        }

        return importedCount
    }
}
