import Foundation
import FoundationModels

@available(iOS 26.0, *)
@Generable(description: "A neutral, evidence-grounded work-event draft for an employee record.")
struct TraceAIEventDraft {
    @Guide(description: "Short factual context. Do not infer intent or legal conclusions.")
    var context: String
    @Guide(description: "Chronological description of only what the supplied material shows.")
    var narrative: String
    @Guide(description: "Observable work impact, or an empty string when not shown.")
    var workImpact: String
    @Guide(description: "Uncertainties or facts the employee should verify before using this draft.")
    var uncertainties: [String]
}

enum AppleIntelligenceError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable: return "此裝置目前無法使用 Apple Intelligence；原始資料仍可手動整理。"
        }
    }
}

/// Generates a reviewable draft only. It never decides whether conduct is bullying or unlawful.
@available(iOS 26.0, *)
enum AppleIntelligenceService {
    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    static func draft(for event: TraceEvent) async throws -> TraceAIEventDraft {
        guard isAvailable else { throw AppleIntelligenceError.unavailable }
        let session = LanguageModelSession(instructions: """
        你是工作事件紀錄整理助手。只根據使用者提供的文字產生中性的草稿。
        不得判定霸凌、違法、動機或責任，不得補寫不存在的時間、人物或對話。
        對不確定的地方放入 uncertainties，並提醒使用者核對原始附件。
        """)

        let evidenceText = event.attachments
            .sorted { $0.orderIndex < $1.orderIndex }
            .map {
                "附件：\($0.fileName)\nOCR/逐字稿：\($0.confirmedText.isEmpty ? $0.rawOCRText : $0.confirmedText)"
            }
            .joined(separator: "\n\n")
        let prompt = """
        請整理以下工作事件。只回傳結構化欄位，不要法律判斷。
        事件標題：\(event.title)
        發生時間：\(event.occurredAt.formatted())
        使用者已有敘述：\(event.narrative)
        工作影響：\(event.workImpact)
        附件材料：
        \(evidenceText.isEmpty ? "（沒有可用附件文字）" : evidenceText)
        """
        let response = try await session.respond(to: prompt, generating: TraceAIEventDraft.self)
        return response.content
    }
}
