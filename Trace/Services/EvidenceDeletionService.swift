import Foundation
import SwiftData

enum EvidenceDeletionError: LocalizedError {
    case couldNotRestore

    var errorDescription: String? {
        switch self {
        case .couldNotRestore:
            return "刪除過程中斷，部分檔案已保留在待清理區。請稍後再試。"
        }
    }
}

@MainActor
enum EvidenceDeletionService {
    static func delete(attachment: EvidenceAttachment, from modelContext: ModelContext) throws {
        try deleteFilesAndModel(attachments: [attachment], event: nil, from: modelContext)
    }

    static func delete(event: TraceEvent, from modelContext: ModelContext) throws {
        try deleteFilesAndModel(attachments: Array(event.attachments), event: event, from: modelContext)
    }

    private static func deleteFilesAndModel(
        attachments: [EvidenceAttachment],
        event: TraceEvent?,
        from modelContext: ModelContext
    ) throws {
        let attachmentIDs = Set(attachments.map(\.id))
        let operationID = UUID()
        let trashDirectory = try EvidenceStore.directory(named: "Operations")
            .appendingPathComponent("trash-\(operationID.uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: trashDirectory, withIntermediateDirectories: true)
        var movedFiles: [(trash: URL, original: URL)] = []

        do {
            for attachment in attachments {
                let original = try EvidenceStore.url(for: attachment)
                try moveIfExists(original, to: trashDirectory, movedFiles: &movedFiles)
                let derived = try EvidenceStore.derivedDirectory(for: attachment)
                try moveIfExists(derived, to: trashDirectory, movedFiles: &movedFiles)
            }

            for attachment in attachments {
                modelContext.delete(attachment)
            }

            // OCR, transcript, and conversation rows use UUID references rather
            // than SwiftData relationships, so they must be removed explicitly.
            let ocrResults = try modelContext.fetch(FetchDescriptor<OCRResult>())
                .filter { attachmentIDs.contains($0.attachmentID) }
            ocrResults.forEach { modelContext.delete($0) }

            let confirmedTranscripts = try modelContext.fetch(FetchDescriptor<ConfirmedTranscript>())
                .filter { attachmentIDs.contains($0.sourceID) }
            confirmedTranscripts.forEach { modelContext.delete($0) }

            let conversationMessages = try modelContext.fetch(FetchDescriptor<ConversationMessage>())
                .filter { attachmentIDs.contains($0.attachmentID) }
            conversationMessages.forEach { modelContext.delete($0) }

            if let event {
                modelContext.delete(event)
            }
            try modelContext.save()
            try FileManager.default.removeItem(at: trashDirectory)
        } catch {
            modelContext.rollback()
            do {
                for moved in movedFiles.reversed() {
                    if FileManager.default.fileExists(atPath: moved.trash.path) {
                        try FileManager.default.moveItem(at: moved.trash, to: moved.original)
                    }
                }
                try FileManager.default.removeItem(at: trashDirectory)
            } catch {
                throw EvidenceDeletionError.couldNotRestore
            }
            throw error
        }
    }

    private static func moveIfExists(
        _ original: URL,
        to trashDirectory: URL,
        movedFiles: inout [(trash: URL, original: URL)]
    ) throws {
        guard FileManager.default.fileExists(atPath: original.path) else { return }
        let trashURL = trashDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.moveItem(at: original, to: trashURL)
        movedFiles.append((trash: trashURL, original: original))
    }
}
