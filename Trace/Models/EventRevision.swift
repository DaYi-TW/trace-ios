import Foundation
import SwiftData

enum EventRevisionSource: String, Codable {
    case original
    case userEdit
    case confirmedAI
}

@Model
final class EventRevision {
    var id: UUID
    var eventID: UUID
    var versionNumber: Int
    var sourceRawValue: String
    var context: String
    var narrative: String
    var workImpact: String
    var uncertainties: [String]
    var createdAt: Date

    var event: TraceEvent?

    init(
        event: TraceEvent,
        versionNumber: Int = 1,
        source: EventRevisionSource = .original,
        context: String = "",
        narrative: String = "",
        workImpact: String = "",
        uncertainties: [String] = []
    ) {
        self.id = UUID()
        self.eventID = event.id
        self.versionNumber = versionNumber
        self.sourceRawValue = source.rawValue
        self.context = context
        self.narrative = narrative
        self.workImpact = workImpact
        self.uncertainties = uncertainties
        self.createdAt = .now
        self.event = event
    }

    var source: EventRevisionSource {
        EventRevisionSource(rawValue: sourceRawValue) ?? .original
    }
}
