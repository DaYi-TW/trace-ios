import AVFoundation
import Foundation
import Speech

enum SpeechTranscriptionError: LocalizedError {
    case unsupportedOS
    case unsupportedLocale
    case noTranscript

    var errorDescription: String? {
        switch self {
        case .unsupportedOS: return "Apple SpeechAnalyzer 需要 iOS 26 或以上。"
        case .unsupportedLocale: return "此裝置目前沒有可用的繁體中文語音模型。"
        case .noTranscript: return "沒有產生可用的逐字稿。"
        }
    }
}

/// iOS 26+ on-device transcription. The caller keeps the original audio untouched.
@available(iOS 26.0, *)
enum SpeechAnalyzerService {
    static func transcribe(fileAt url: URL, locale: Locale = Locale(identifier: "zh-TW")) async throws -> String {
        guard let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            throw SpeechTranscriptionError.unsupportedLocale
        }

        let transcriber = SpeechTranscriber(locale: supportedLocale, preset: .transcription)
        async let transcriptionFuture = try transcriber.results.reduce("") { text, result in
            text + String(result.text.characters)
        }

        let audioFile = try AVAudioFile(forReading: url)
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        if let lastSample = try await analyzer.analyzeSequence(from: audioFile) {
            try await analyzer.finalizeAndFinish(through: lastSample)
        } else {
            await analyzer.cancelAndFinishNow()
        }

        let transcript = try await transcriptionFuture
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscript.isEmpty else { throw SpeechTranscriptionError.noTranscript }
        return trimmedTranscript
    }
}
