import UIKit
import Vision

enum OCRServiceError: LocalizedError {
    case unreadableImage

    var errorDescription: String? { "無法讀取這張圖片。" }
}

enum OCRService {
    static func recognizeText(in imageData: Data) async throws -> String {
        guard let image = UIImage(data: imageData), let cgImage = image.cgImage else {
            throw OCRServiceError.unreadableImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hant", "en-US"]
            request.usesLanguageCorrection = true

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
