import CryptoKit
import Foundation
import SwiftData

enum BackupServiceError: LocalizedError {
    case emptyPassword
    case unsupportedVersion
    case invalidBackup

    var errorDescription: String? {
        switch self {
        case .emptyPassword: return "請輸入備份密碼。"
        case .unsupportedVersion: return "此備份版本目前不支援。"
        case .invalidBackup: return "備份檔案格式不正確，或密碼錯誤。"
        }
    }
}

struct TraceBackupEnvelope: Codable {
    let version: Int
    let createdAt: Date
    let salt: Data
    let iterations: Int
    let ciphertext: Data
}

private struct TraceBackupPayload: Codable {
    let exportedAt: Date
    let events: [BackupEvent]
}

private struct BackupEvent: Codable {
    let title: String
    let occurredAt: Date
    let context: String
    let narrative: String
    let workImpact: String
    let createdAt: Date
    let updatedAt: Date
    let attachments: [BackupAttachment]
}

private struct BackupAttachment: Codable {
    let fileName: String
    let kind: String
    let sha256: String
    let importedAt: Date
    let sourceDescription: String
    let imageState: String
    let displayedMessageTime: String
    let userConfirmedDate: String
    let dateAccuracy: String
    let rawOCRText: String
    let confirmedText: String
    let ocrStatus: String
    let originalData: Data
}

@MainActor
enum BackupService {
    static func createBackup(events: [TraceEvent], password: String) throws -> URL {
        guard !password.isEmpty else { throw BackupServiceError.emptyPassword }
        let backups = try events.map { event in
            BackupEvent(
                title: event.title,
                occurredAt: event.occurredAt,
                context: event.context,
                narrative: event.narrative,
                workImpact: event.workImpact,
                createdAt: event.createdAt,
                updatedAt: event.updatedAt,
                attachments: try event.attachments.map { attachment in
                    BackupAttachment(
                        fileName: attachment.fileName,
                        kind: attachment.kindRawValue,
                        sha256: attachment.sha256,
                        importedAt: attachment.importedAt,
                        sourceDescription: attachment.sourceDescription,
                        imageState: attachment.imageState,
                        displayedMessageTime: attachment.displayedMessageTime,
                        userConfirmedDate: attachment.userConfirmedDate,
                        dateAccuracy: attachment.dateAccuracy,
                        rawOCRText: attachment.rawOCRText,
                        confirmedText: attachment.confirmedText,
                        ocrStatus: attachment.ocrStatus,
                        originalData: try Data(contentsOf: EvidenceStore.url(for: attachment))
                    )
                }
            )
        }
        let payload = TraceBackupPayload(exportedAt: .now, events: backups)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let plaintext = try encoder.encode(payload)
        let salt = Data((0..<16).map { _ in UInt8.random(in: .min ... .max) })
        let iterations = 210_000
        let key = deriveKey(password: password, salt: salt, iterations: iterations)
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else { throw BackupServiceError.invalidBackup }
        let envelope = TraceBackupEnvelope(
            version: 1,
            createdAt: .now,
            salt: salt,
            iterations: iterations,
            ciphertext: combined
        )
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("Trace-Backup-\(Int(Date.now.timeIntervalSince1970)).tracebackup")
        try encoder.encode(envelope).write(to: output, options: [.atomic, .completeFileProtection])
        return output
    }

    static func restoreBackup(at url: URL, password: String, into modelContext: ModelContext) throws -> Int {
        guard !password.isEmpty else { throw BackupServiceError.emptyPassword }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(TraceBackupEnvelope.self, from: Data(contentsOf: url))
        guard envelope.version == 1 else { throw BackupServiceError.unsupportedVersion }
        do {
            let key = deriveKey(password: password, salt: envelope.salt, iterations: envelope.iterations)
            let sealed = try AES.GCM.SealedBox(combined: envelope.ciphertext)
            let plaintext = try AES.GCM.open(sealed, using: key)
            let payload = try decoder.decode(TraceBackupPayload.self, from: plaintext)
            for backupEvent in payload.events {
                let event = TraceEvent(
                    title: backupEvent.title,
                    occurredAt: backupEvent.occurredAt,
                    context: backupEvent.context,
                    narrative: backupEvent.narrative,
                    workImpact: backupEvent.workImpact
                )
                event.createdAt = backupEvent.createdAt
                event.updatedAt = backupEvent.updatedAt
                modelContext.insert(event)
                for backupAttachment in backupEvent.attachments {
                    let kind = EvidenceKind(rawValue: backupAttachment.kind) ?? .document
                    let attachment = try EvidenceStore.store(
                        data: backupAttachment.originalData,
                        preferredFileName: backupAttachment.fileName,
                        kind: kind
                    )
                    attachment.sourceDescription = backupAttachment.sourceDescription
                    attachment.imageState = backupAttachment.imageState
                    attachment.displayedMessageTime = backupAttachment.displayedMessageTime
                    attachment.userConfirmedDate = backupAttachment.userConfirmedDate
                    attachment.dateAccuracy = backupAttachment.dateAccuracy
                    attachment.rawOCRText = backupAttachment.rawOCRText
                    attachment.confirmedText = backupAttachment.confirmedText
                    attachment.ocrStatus = backupAttachment.ocrStatus
                    attachment.importedAt = backupAttachment.importedAt
                    attachment.event = event
                    modelContext.insert(attachment)
                }
            }
            return payload.events.count
        } catch {
            throw BackupServiceError.invalidBackup
        }
    }

    private static func deriveKey(password: String, salt: Data, iterations: Int) -> SymmetricKey {
        let passwordKey = SymmetricKey(data: Data(password.utf8))
        var initial = salt
        initial.append(contentsOf: [0, 0, 0, 1])
        var u = Data(HMAC<SHA256>.authenticationCode(for: initial, using: passwordKey))
        var output = [UInt8](u)
        if iterations > 1 {
            for _ in 1..<iterations {
                u = Data(HMAC<SHA256>.authenticationCode(for: u, using: passwordKey))
                let bytes = [UInt8](u)
                for index in output.indices { output[index] ^= bytes[index] }
            }
        }
        return SymmetricKey(data: Data(output))
    }
}
