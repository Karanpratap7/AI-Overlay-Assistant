import Foundation
import Vision
import AppKit

/// On-device OCR service powered by the Apple Vision framework.
/// Runs entirely locally — no API key, no network access.
final class VisionService: ObservableObject {

    // MARK: - Types

    struct OCRResult {
        let fullText: String
        let blocks: [TextBlock]
        let confidence: Float

        struct TextBlock {
            let text: String
            let boundingBox: CGRect
            let confidence: Float
        }
    }

    enum VisionError: Error, LocalizedError {
        case invalidImage
        case noTextDetected
        case visionError(String)

        var errorDescription: String? {
            switch self {
            case .invalidImage: return "Invalid image data"
            case .noTextDetected: return "No text detected in image"
            case .visionError(let msg): return "Vision error: \(msg)"
            }
        }
    }

    // MARK: - Published State

    @Published var isProcessing = false
    @Published var lastOCRResult: OCRResult?

    // MARK: - OCR

    /// Performs OCR on a base64-encoded image using the local Vision framework.
    func performOCR(imageBase64: String) async throws -> OCRResult {
        guard let data = Data(base64Encoded: imageBase64) else {
            throw VisionError.invalidImage
        }
        return try await performOCR(imageData: data)
    }

    /// Performs OCR on raw image data using the local Vision framework.
    func performOCR(imageData: Data) async throws -> OCRResult {
        guard let image = NSImage(data: imageData),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw VisionError.invalidImage
        }

        await MainActor.run { self.isProcessing = true }
        defer {
            Task { @MainActor in self.isProcessing = false }
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: VisionError.visionError(error.localizedDescription))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: VisionError.noTextDetected)
                    return
                }

                let blocks: [OCRResult.TextBlock] = observations.compactMap { observation in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return OCRResult.TextBlock(
                        text: candidate.string,
                        boundingBox: observation.boundingBox,
                        confidence: candidate.confidence
                    )
                }

                // Sort in natural reading order: top-to-bottom, then left-to-right.
                let sorted = blocks.sorted { a, b in
                    let yA = a.boundingBox.midY
                    let yB = b.boundingBox.midY
                    if abs(yA - yB) > 0.01 { return yA > yB }
                    return a.boundingBox.minX < b.boundingBox.minX
                }

                let fullText = sorted.map { $0.text }.joined(separator: "\n")
                if fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continuation.resume(throwing: VisionError.noTextDetected)
                    return
                }

                let averageConfidence = sorted.isEmpty ? 0 : sorted.reduce(0) { $0 + $1.confidence } / Float(sorted.count)
                let result = OCRResult(
                    fullText: fullText,
                    blocks: sorted,
                    confidence: averageConfidence
                )

                continuation.resume(returning: result)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.minimumTextHeight = 0.01

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}