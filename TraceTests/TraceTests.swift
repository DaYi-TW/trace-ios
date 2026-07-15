import SwiftData
import XCTest
@testable import Trace

@MainActor
final class TraceTests: XCTestCase {
    func testProjectTestTargetIsRunnable() {
        XCTAssertTrue(true)
    }

    func testLegacyEventGetsOriginalRevision() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let event = TraceEvent(
            title: "測試事件",
            context: "辦公室",
            narrative: "原始陳述",
            workImpact: "工作影響"
        )
        context.insert(event)
        try context.save()

        let inserted = try DataMigrationService.backfillOriginalRevisions(in: context)

        XCTAssertEqual(inserted, 1)
        XCTAssertEqual(event.revisions.count, 1)
        XCTAssertEqual(event.currentRevision?.narrative, "原始陳述")
        XCTAssertEqual(event.currentRevision?.source, .original)
    }

    func testEvidenceIntegrityDetectsTampering() throws {
        let data = Data("original evidence".utf8)
        let attachment = try EvidenceStore.store(
            data: data,
            preferredFileName: "evidence.txt",
            kind: .document
        )
        let url = try EvidenceStore.url(for: attachment)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(try EvidenceStore.verify(attachment))
        try Data("tampered evidence".utf8).write(to: url, options: .atomic)
        XCTAssertFalse(try EvidenceStore.verify(attachment))
        XCTAssertEqual(attachment.integrityStatus, .mismatch)
    }

    func testDeletingEventRemovesOriginalFileAndModel() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let attachment = try EvidenceStore.store(
            data: Data("delete me".utf8),
            preferredFileName: "delete.txt",
            kind: .document
        )
        let event = TraceEvent(title: "待刪除事件", narrative: "原始資料")
        attachment.event = event
        event.attachments.append(attachment)
        context.insert(event)
        context.insert(attachment)
        try context.save()
        let url = try EvidenceStore.url(for: attachment)

        try EvidenceDeletionService.delete(event: event, from: context)

        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertTrue(try context.fetch(FetchDescriptor<TraceEvent>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<EvidenceAttachment>()).isEmpty)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: TraceSchemaV2.self)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
