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
        let folder = try evidenceDirectory()
        let safeName = preferredFileName.replacingOccurrences(of: "/", with: "-")
        let storedName = "\(UUID().uuidString)-\(safeName)"
        let destination = folder.appendingPathComponent(storedName)
        try data.write(to: destination, options: [.atomic, .completeFileProtection])

        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return EvidenceAttachment(
            fileName: safeName,
            relativePath: storedName,
            kind: kind,
            sha256: digest
        )
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

    private static func evidenceDirectory() throws -> URL {
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw EvidenceStoreError.missingApplicationSupportDirectory
        }
        let folder = applicationSupport.appendingPathComponent("Trace/Evidence", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
}
