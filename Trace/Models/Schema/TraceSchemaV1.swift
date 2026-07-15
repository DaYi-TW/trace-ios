import Foundation
import SwiftData

enum TraceSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [TraceSchemaV1.TraceEvent.self, TraceSchemaV1.EvidenceAttachment.self]
    }

    @Model
    final class TraceEvent {
        var id: UUID
        var title: String
        var occurredAt: Date
        var context: String
        var narrative: String
        var workImpact: String
        var createdAt: Date
        var updatedAt: Date

        @Relationship(deleteRule: .cascade, inverse: \EvidenceAttachment.event)
        var attachments: [EvidenceAttachment] = []

        init(
            title: String,
            occurredAt: Date = .now,
            context: String = "",
            narrative: String = "",
            workImpact: String = ""
        ) {
            self.id = UUID()
            self.title = title
            self.occurredAt = occurredAt
            self.context = context
            self.narrative = narrative
            self.workImpact = workImpact
            self.createdAt = .now
            self.updatedAt = .now
        }
    }

    @Model
    final class EvidenceAttachment {
        var id: UUID
        var fileName: String
        var relativePath: String
        var kindRawValue: String
        var sha256: String
        var importedAt: Date
        var sourceDescription: String
        var imageState: String
        var displayedMessageTime: String
        var userConfirmedDate: String
        var dateAccuracy: String
        var rawOCRText: String
        var confirmedText: String
        var ocrStatus: String
        var event: TraceEvent?

        init(
            fileName: String,
            relativePath: String,
            kindRawValue: String,
            sha256: String
        ) {
            self.id = UUID()
            self.fileName = fileName
            self.relativePath = relativePath
            self.kindRawValue = kindRawValue
            self.sha256 = sha256
            self.importedAt = .now
            self.sourceDescription = ""
            self.imageState = "不確定"
            self.displayedMessageTime = ""
            self.userConfirmedDate = ""
            self.dateAccuracy = "未知"
            self.rawOCRText = ""
            self.confirmedText = ""
            self.ocrStatus = "尚未辨識"
        }
    }
}
