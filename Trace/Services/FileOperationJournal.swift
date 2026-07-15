import Foundation

struct TraceFileOperation: Codable {
    let id: UUID
    let kind: String
    let paths: [String]
    let createdAt: Date
}

enum TraceFileOperationJournal {
    static func begin(kind: String, paths: [URL]) throws -> URL {
        let id = UUID()
        let record = TraceFileOperation(
            id: id,
            kind: kind,
            paths: paths.map(\.path),
            createdAt: .now
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let journalURL = try EvidenceStore.directory(named: "Operations")
            .appendingPathComponent("\(id.uuidString).json")
        try encoder.encode(record).write(to: journalURL, options: [.atomic, .completeFileProtection])
        return journalURL
    }

    static func finish(_ journalURL: URL) throws {
        if FileManager.default.fileExists(atPath: journalURL.path) {
            try FileManager.default.removeItem(at: journalURL)
        }
    }
}
