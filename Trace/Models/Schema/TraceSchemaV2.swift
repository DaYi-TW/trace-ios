import SwiftData

enum TraceSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            TraceEvent.self,
            EvidenceAttachment.self,
            EventRevision.self,
            OCRResult.self,
            ConfirmedTranscript.self
        ]
    }
}
