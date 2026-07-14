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

    func touch() {
        updatedAt = .now
    }
}
