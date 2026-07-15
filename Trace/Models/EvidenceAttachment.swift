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
    var byteCount: Int64
    var uti: String
    var importedAt: Date
    var fileCreatedAt: Date?
    var integrityStatusRawValue: String
    var orderIndex: Int
    var sourceDescription: String
    var imageState: String
    var displayedMessageTime: String
    var userConfirmedDate: String
    var dateAccuracy: String
    var rawOCRText: String
    var confirmedText: String
    var ocrStatus: String
    // Chat screenshot metadata. Values are user-confirmed or explicitly left unknown.
    var sourceApp: String = ""
    var conversationType: String = ""
    var sideMapping: String = ""
    var screenshotCompleteness: String = ""
    var latestOCRResultID: UUID? = nil
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
        self.byteCount = 0
        self.uti = "public.data"
        self.importedAt = .now
        self.fileCreatedAt = nil
        self.integrityStatusRawValue = EvidenceIntegrityStatus.valid.rawValue
        self.orderIndex = 0
        self.sourceDescription = sourceDescription
        self.imageState = imageState
        self.displayedMessageTime = ""
        self.userConfirmedDate = ""
        self.dateAccuracy = "未知"
        self.rawOCRText = ""
        self.confirmedText = ""
        self.ocrStatus = "尚未辨識"
    }

    var integrityStatus: EvidenceIntegrityStatus {
        get { EvidenceIntegrityStatus(rawValue: integrityStatusRawValue) ?? .unverified }
        set { integrityStatusRawValue = newValue.rawValue }
    }
}

enum EvidenceIntegrityStatus: String, Codable {
    case unverified
    case valid
    case mismatch
    case missing
}
