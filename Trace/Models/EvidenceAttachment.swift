import Foundation
import SwiftData

enum EvidenceKind: String, CaseIterable, Identifiable {
    case image
    case document
    case audio

    var id: String { rawValue }
    var label: String {
        switch self {
        case .image: return "圖片"
        case .document: return "文件"
        case .audio: return "音檔"
        }
    }
}

@Model
final class EvidenceAttachment {
    var id: UUID
    var fileName: String
    var relativePath: String
    var kindRawValue: String
    var sha256: String
    var importedAt: Date
    var sourceDescription: String
    var imageState: String
    var displayedMessageTime: String
    var userConfirmedDate: String
    var dateAccuracy: String
    var rawOCRText: String
    var confirmedText: String
    var ocrStatus: String
    var event: TraceEvent?

    var kind: EvidenceKind { EvidenceKind(rawValue: kindRawValue) ?? .document }

    init(
        fileName: String,
        relativePath: String,
        kind: EvidenceKind,
        sha256: String,
        sourceDescription: String = "",
        imageState: String = "不確定"
    ) {
        self.id = UUID()
        self.fileName = fileName
        self.relativePath = relativePath
        self.kindRawValue = kind.rawValue
        self.sha256 = sha256
        self.importedAt = .now
        self.sourceDescription = sourceDescription
        self.imageState = imageState
        self.displayedMessageTime = ""
        self.userConfirmedDate = ""
        self.dateAccuracy = "未知"
        self.rawOCRText = ""
        self.confirmedText = ""
        self.ocrStatus = "尚未辨識"
    }
}
