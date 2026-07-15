import UIKit
import Vision

enum OCRServiceError: LocalizedError {
    case unreadableImage

    var errorDescription: String? { "無法讀取這張圖片。" }
}

enum OCRService {
    static let localeIdentifiers = ["zh-Hant", "en-US"]

    static func recognize(in imageData: Data) async throws -> OCRDraft {
        guard let image = UIImage(data: imageData), let cgImage = image.cgImage else {
            throw OCRServiceError.unreadableImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = (request.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { observation -> OCRTextObservation? in
                        guard let candidate = observation.topCandidates(1).first,
                              !candidate.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            return nil
                        }
                        let box = observation.boundingBox
                        return OCRTextObservation(
                            id: UUID(),
                            text: candidate.string,
                            confidence: Double(candidate.confidence),
                            x: Double(box.origin.x),
                            y: Double(box.origin.y),
                            width: Double(box.size.width),
                            height: Double(box.size.height)
                        )
                    }
                    .sorted {
                        if abs($0.midpointY - $1.midpointY) > 0.02 {
                            return $0.midpointY > $1.midpointY
                        }
                        return $0.x < $1.x
                    }

                let text = observations.map(\.text).joined(separator: "\n")
                continuation.resume(returning: OCRDraft(
                    rawText: text,
                    observations: observations,
                    engine: "Vision VNRecognizeTextRequest",
                    localeIdentifiers: localeIdentifiers
                ))
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = localeIdentifiers
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

    static func recognizeText(in imageData: Data) async throws -> String {
        (try await recognize(in: imageData)).rawText
    }
}
