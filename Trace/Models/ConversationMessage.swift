import Foundation
import SwiftData

enum ConversationSide: String, CaseIterable, Identifiable {
    case left
    case right
    case system
    case unknown

    var id: String { rawValue }

    var label: String {
        switch self {
        case .left: return "左側"
        case .right: return "右側"
        case .system: return "系統訊息"
        case .unknown: return "無法辨識"
        }
    }
}

enum ConversationMessageKind: String, CaseIterable, Identifiable {
    case message
    case quoted
    case system
    case attachment
    case unknown

    var id: String { rawValue }
}

/// A user-reviewable line extracted from a chat screenshot.
@Model
final class ConversationMessage {
    var id: UUID
    var attachmentID: UUID
    var orderIndex: Int
    var sideRawValue: String
    var text: String
    var kindRawValue: String
    var confidence: Double
    var isConfirmed: Bool
    var displayedTime: String
    var createdAt: Date

    init(
        attachmentID: UUID,
        orderIndex: Int,
        side: ConversationSide,
        text: String,
        confidence: Double = 0,
        kind: ConversationMessageKind = .message
    ) {
        self.id = UUID()
        self.attachmentID = attachmentID
        self.orderIndex = orderIndex
        self.sideRawValue = side.rawValue
        self.text = text
        self.kindRawValue = kind.rawValue
        self.confidence = confidence
        self.isConfirmed = false
        self.displayedTime = ""
        self.createdAt = .now
    }

    var side: ConversationSide {
        get { ConversationSide(rawValue: sideRawValue) ?? .unknown }
        set { sideRawValue = newValue.rawValue }
    }

    var kind: ConversationMessageKind {
        get { ConversationMessageKind(rawValue: kindRawValue) ?? .unknown }
        set { kindRawValue = newValue.rawValue }
    }
}
