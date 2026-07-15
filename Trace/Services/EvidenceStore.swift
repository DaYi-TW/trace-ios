import CryptoKit
import Foundation
import UniformTypeIdentifiers

enum EvidenceStoreError: LocalizedError {
    case missingApplicationSupportDirectory
    case unsupportedFile

    var errorDescription: String? {
        switch self {
        case .missingApplicationSupportDirectory: return "無法建立附件儲存位置。"
        case .unsupportedFile: return "此檔案格式目前無法匯入。"
        }
    }
}

enum EvidenceStore {
    static func imageFileExtension(for data: Data) -> String {
        let signature = [UInt8](data.prefix(12))
        if signature.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "png" }
        if signature.starts(with: [0xFF, 0xD8, 0xFF]) { return "jpg" }
        if signature.count >= 12,
           Array(signature[0...3]) == [0x52, 0x49, 0x46, 0x46],
           Array(signature[8...11]) == [0x57, 0x45, 0x42, 0x50] { return "webp" }
        return "img"
    }

    static func store(data: Data, preferredFileName: String, kind: EvidenceKind) throws -> EvidenceAttachment {
        let safeName = sanitizedFileName(preferredFileName)
        let fileExtension = URL(fileURLWithPath: safeName).pathExtension.isEmpty
            ? defaultFileExtension(for: kind)
            : URL(fileURLWithPath: safeName).pathExtension
        let storedName = "\(UUID().uuidString)-original.\(fileExtension)"
        let stagingDirectory = try directory(named: "Staging")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        let stagingURL = stagingDirectory.appendingPathComponent(storedName)
        let destination = try evidenceDirectory().appendingPathComponent(storedName)
        let journalURL = try TraceFileOperationJournal.begin(
            kind: "store",
            paths: [stagingURL, destination]
        )
        var committed = false
        defer {
            if !committed {
                try? FileManager.default.removeItem(at: stagingDirectory)
            }
        }

        try data.write(to: stagingURL, options: [.atomic, .completeFileProtection])
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        try FileManager.default.moveItem(at: stagingURL, to: destination)
        try FileManager.default.removeItem(at: stagingDirectory)
        committed = true
        try TraceFileOperationJournal.finish(journalURL)

        let attachment = EvidenceAttachment(
            fileName: safeName,
            relativePath: storedName,
            kind: kind,
            sha256: digest
        )
        attachment.byteCount = Int64(data.count)
        attachment.uti = UTType(filenameExtension: fileExtension)?.identifier ?? "public.data"
        attachment.fileCreatedAt = .now
        attachment.integrityStatus = .valid
        return attachment
    }

    static func store(fileAt sourceURL: URL) throws -> EvidenceAttachment {
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessing { sourceURL.stopAccessingSecurityScopedResource() }
        }

        let data = try Data(contentsOf: sourceURL)
        let type = UTType(filenameExtension: sourceURL.pathExtension)
        let kind: EvidenceKind
        if type?.conforms(to: .image) == true {
            kind = .image
        } else if type?.conforms(to: .audio) == true {
            kind = .audio
        } else if type?.conforms(to: .pdf) == true {
            kind = .document
        } else {
            throw EvidenceStoreError.unsupportedFile
        }
        return try store(data: data, preferredFileName: sourceURL.lastPathComponent, kind: kind)
    }

    static func url(for attachment: EvidenceAttachment) throws -> URL {
        try evidenceDirectory().appendingPathComponent(attachment.relativePath)
    }

    static func verify(_ attachment: EvidenceAttachment) throws -> Bool {
        let fileURL: URL
        do {
            fileURL = try url(for: attachment)
        } catch {
            attachment.integrityStatus = .missing
            return false
        }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            attachment.integrityStatus = .missing
            return false
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            let valid = digest == attachment.sha256
            attachment.integrityStatus = valid ? .valid : .mismatch
            attachment.byteCount = Int64(data.count)
            return valid
        } catch {
            attachment.integrityStatus = .missing
            return false
        }
    }

    static func derivedDirectory(for attachment: EvidenceAttachment) throws -> URL {
        try directory(named: "Derived").appendingPathComponent(attachment.id.uuidString, isDirectory: true)
    }

    static func rootDirectory() throws -> URL {
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw EvidenceStoreError.missingApplicationSupportDirectory
        }
        let folder = applicationSupport.appendingPathComponent("Trace", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static func directory(named name: String) throws -> URL {
        let folder = try rootDirectory().appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private static func evidenceDirectory() throws -> URL {
        try directory(named: "Evidence")
    }

    private static func sanitizedFileName(_ name: String) -> String {
        let replaced = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
        let filtered = replaced.filter { character in
            !character.isNewline && character != "\u{0}" && character != "\u{7F}"
        }
        return filtered.isEmpty ? "attachment.bin" : filtered
    }

    private static func defaultFileExtension(for kind: EvidenceKind) -> String {
        switch kind {
        case .image: return "img"
        case .document: return "pdf"
        case .audio: return "m4a"
        }
    }
}
