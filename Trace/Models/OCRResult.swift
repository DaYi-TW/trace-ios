import Foundation
import SwiftData

@Model
final class OCRResult {
    var id: UUID
    var attachmentID: UUID
    var engine: String
    var localeIdentifiers: [String]
    var rawText: String
    var observationsData: Data
    var statusRawValue: String
    var createdAt: Date

    init(
        attachmentID: UUID,
        engine: String = "Vision",
        localeIdentifiers: [String] = ["zh-Hant", "en-US"],
        rawText: String = "",
        observationsData: Data = Data(),
        status: String = "completed"
    ) {
        self.id = UUID()
        self.attachmentID = attachmentID
        self.engine = engine
        self.localeIdentifiers = localeIdentifiers
        self.rawText = rawText
        self.observationsData = observationsData
        self.statusRawValue = status
        self.createdAt = .now
    }
}

@Model
final class ConfirmedTranscript {
    var id: UUID
    var sourceID: UUID
    var text: String
    var revisionNumber: Int
    var confirmedAt: Date

    init(sourceID: UUID, text: String, revisionNumber: Int = 1) {
        self.id = UUID()
        self.sourceID = sourceID
        self.text = text
        self.revisionNumber = revisionNumber
        self.confirmedAt = .now
    }
}
