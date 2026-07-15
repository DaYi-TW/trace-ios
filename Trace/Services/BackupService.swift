import CryptoKit
import Foundation
import SwiftData

enum BackupServiceError: LocalizedError {
    case emptyPassword
    case weakPassword
    case unsupportedVersion
    case invalidBackup

    var errorDescription: String? {
        switch self {
        case .emptyPassword:
            return "請輸入備份密碼。"
        case .weakPassword:
            return "備份密碼至少需要 12 個字元，並包含字母與數字或符號。"
        case .unsupportedVersion:
            return "這個備份版本目前不受支援。"
        case .invalidBackup:
            return "備份檔無法驗證或已損毀。"
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
    // Existing 210,000-iteration exports remain readable; new exports use the
    // stronger recommended value. Bounds also prevent attacker-controlled KDF DoS.
    static let recommendedIterations = 600_000
    static let minimumSupportedIterations = 100_000
    static let maximumSupportedIterations = 1_000_000
    static let maximumBackupBytes: Int64 = 512 * 1024 * 1024

    static func isAcceptablePassword(_ password: String) -> Bool {
        let trimmed = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 12 else { return false }
        let hasLetter = trimmed.contains { $0.isLetter }
        let hasNumber = trimmed.contains { $0.isNumber }
        let hasSymbol = trimmed.contains { !$0.isLetter && !$0.isNumber && !$0.isWhitespace }
        return hasLetter && (hasNumber || hasSymbol)
    }

    static func createBackup(events: [TraceEvent], password: String) throws -> URL {
        guard !password.isEmpty else { throw BackupServiceError.emptyPassword }
        guard isAcceptablePassword(password) else { throw BackupServiceError.weakPassword }

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
        let key = deriveKey(password: password, salt: salt, iterations: recommendedIterations)
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else { throw BackupServiceError.invalidBackup }

        let envelope = TraceBackupEnvelope(
            version: 1,
            createdAt: .now,
            salt: salt,
            iterations: recommendedIterations,
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
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }

        var storedAttachments: [EvidenceAttachment] = []
        do {
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
            guard let fileSize = resourceValues.fileSize,
                  Int64(fileSize) <= maximumBackupBytes else {
                throw BackupServiceError.invalidBackup
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let envelope = try decoder.decode(TraceBackupEnvelope.self, from: Data(contentsOf: url))
            guard envelope.version == 1 else { throw BackupServiceError.unsupportedVersion }
            guard (minimumSupportedIterations...maximumSupportedIterations).contains(envelope.iterations) else {
                throw BackupServiceError.invalidBackup
            }

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
                    storedAttachments.append(attachment)
                    guard attachment.sha256.caseInsensitiveCompare(backupAttachment.sha256) == .orderedSame else {
                        throw BackupServiceError.invalidBackup
                    }
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

            try modelContext.save()
            return payload.events.count
        } catch let error as BackupServiceError {
            removeStoredAttachments(storedAttachments)
            modelContext.rollback()
            throw error
        } catch {
            removeStoredAttachments(storedAttachments)
            modelContext.rollback()
            throw BackupServiceError.invalidBackup
        }
    }

    private static func removeStoredAttachments(_ attachments: [EvidenceAttachment]) {
        for attachment in attachments {
            if let url = try? EvidenceStore.url(for: attachment) {
                try? FileManager.default.removeItem(at: url)
            }
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
