import Foundation
import SwiftData

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
    var currentRevisionID: UUID?
    var deletedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \EvidenceAttachment.event)
    var attachments: [EvidenceAttachment] = []

    @Relationship(deleteRule: .cascade, inverse: \EventRevision.event)
    var revisions: [EventRevision] = []

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
        self.currentRevisionID = nil
        self.deletedAt = nil
    }

    func touch() {
        updatedAt = .now
    }

    var currentRevision: EventRevision? {
        if let currentRevisionID {
            return revisions.first { $0.id == currentRevisionID }
        }
        return revisions.max { $0.versionNumber < $1.versionNumber }
    }
}
