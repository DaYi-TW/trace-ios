import Foundation

enum TraceSharedConfiguration {
    /// Register this identifier for both targets under Signing & Capabilities > App Groups.
    static let appGroupIdentifier = "group.tw.dayi.trace"
}

struct PendingImportItem: Codable, Identifiable {
    let id: UUID
    let storedFileName: String
    let originalFileName: String
    let sourceDescription: String
}

struct PendingImportBatch: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    let items: [PendingImportItem]
}

enum SharedImportStore {
    static func write(images: [(data: Data, fileName: String)]) throws -> PendingImportBatch {
        let batch = PendingImportBatch(
            id: UUID(),
            createdAt: .now,
            items: images.enumerated().map { index, image in
                PendingImportItem(
                    id: UUID(),
                    storedFileName: "\(index + 1)-\(UUID().uuidString).jpg",
                    originalFileName: image.fileName,
                    sourceDescription: "透過 iOS 分享選單加入"
                )
            }
        )
        let directory = try batchDirectory(for: batch.id)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (index, image) in images.enumerated() {
            let item = batch.items[index]
            try image.data.write(
                to: directory.appendingPathComponent(item.storedFileName),
                options: [.atomic, .completeFileProtection]
            )
        }
        let manifest = try JSONEncoder.trace.encode(batch)
        try manifest.write(
            to: directory.appendingPathComponent("manifest.json"),
            options: [.atomic, .completeFileProtection]
        )
        return batch
    }

    static func pendingBatches() throws -> [(PendingImportBatch, URL)] {
        let root = try rootDirectory()
        let directories = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        return try directories.compactMap { directory in
            let manifestURL = directory.appendingPathComponent("manifest.json")
            guard FileManager.default.fileExists(atPath: manifestURL.path) else { return nil }
            let batch = try JSONDecoder.trace.decode(PendingImportBatch.self, from: Data(contentsOf: manifestURL))
            return (batch, directory)
        }
    }

    static func remove(batchDirectory: URL) throws {
        try FileManager.default.removeItem(at: batchDirectory)
    }

    private static func batchDirectory(for id: UUID) throws -> URL {
        try rootDirectory().appendingPathComponent(id.uuidString, isDirectory: true)
    }

    private static func rootDirectory() throws -> URL {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: TraceSharedConfiguration.appGroupIdentifier
        ) else {
            throw SharedImportError.unavailableContainer
        }
        let root = container.appendingPathComponent("PendingImports", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}

enum SharedImportError: LocalizedError {
    case unavailableContainer

    var errorDescription: String? {
        "無法存取共享資料夾。請確認主 App 和分享擴充都已啟用相同的 App Group。"
    }
}

private extension JSONEncoder {
    static var trace: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var trace: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
