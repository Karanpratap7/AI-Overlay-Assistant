import Foundation
import Vision
import AppKit

/// Google Cloud Vision API service for OCR text extraction from screenshots.
/// Extracts text + layout information from captured screen regions.
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
        case noAPIKey
        case invalidImage
        case apiError(String)
        case noTextDetected

        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "Google Vision API key not configured"
            case .invalidImage: return "Invalid image data"
            case .apiError(let msg): return "Vision API error: \(msg)"
            case .noTextDetected: return "No text detected in image"
            }
        }
    }

    // MARK: - Published State

    @Published var isProcessing = false
    @Published var lastOCRResult: OCRResult?

    // MARK: - Properties

    private let keychain = KeychainService.shared

    // MARK: - OCR

    /// Performs OCR on a base64-encoded image using Google Cloud Vision API.
    func performOCR(imageBase64: String) async throws -> OCRResult {
        guard let apiKey = keychain.retrieve(key: .googleVisionKey) else {
            throw VisionError.noAPIKey
        }

        await MainActor.run { self.isProcessing = true }
        defer {
            Task { @MainActor in self.isProcessing = false }
        }

        let url = URL(string: "https://vision.googleapis.com/v1/images:annotate?key=\(apiKey)")!

        let body: [String: Any] = [
            "requests": [
                [
                    "image": ["content": imageBase64],
                    "features": [
                        ["type": "TEXT_DETECTION", "maxResults": 50],
                        ["type": "DOCUMENT_TEXT_DETECTION", "maxResults": 1]
                    ]
                ]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw VisionError.apiError("HTTP \(statusCode)")
        }

        return try parseVisionResponse(data)
    }

    // MARK: - Parse Response

    private func parseVisionResponse(_ data: Data) throws -> OCRResult {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let responses = json["responses"] as? [[String: Any]],
              let firstResponse = responses.first else {
            throw VisionError.apiError("Invalid response format")
        }

        // Check for errors
        if let error = firstResponse["error"] as? [String: Any],
           let message = error["message"] as? String {
            throw VisionError.apiError(message)
        }

        // Extract full text from document text detection
        var fullText = ""
        if let fullTextAnnotation = firstResponse["fullTextAnnotation"] as? [String: Any],
           let text = fullTextAnnotation["text"] as? String {
            fullText = text
        }

        // Extract individual text blocks
        var blocks: [OCRResult.TextBlock] = []
        if let textAnnotations = firstResponse["textAnnotations"] as? [[String: Any]] {
            // Skip first element (it's the full text)
            for annotation in textAnnotations.dropFirst() {
                let text = annotation["description"] as? String ?? ""
                let confidence = (annotation["confidence"] as? NSNumber)?.floatValue ?? 0.0

                var boundingBox = CGRect.zero
                if let boundingPoly = annotation["boundingPoly"] as? [String: Any],
                   let vertices = boundingPoly["vertices"] as? [[String: Any]] {
                    if vertices.count >= 4 {
                        let x = (vertices[0]["x"] as? NSNumber)?.doubleValue ?? 0
                        let y = (vertices[0]["y"] as? NSNumber)?.doubleValue ?? 0
                        let x2 = (vertices[2]["x"] as? NSNumber)?.doubleValue ?? 0
                        let y2 = (vertices[2]["y"] as? NSNumber)?.doubleValue ?? 0
                        boundingBox = CGRect(x: x, y: y, width: x2 - x, height: y2 - y)
                    }
                }

                blocks.append(OCRResult.TextBlock(text: text, boundingBox: boundingBox, confidence: confidence))
            }
        }

        if fullText.isEmpty && blocks.isEmpty {
            throw VisionError.noTextDetected
        }

        // Calculate overall confidence
        let avgConfidence: Float = blocks.isEmpty ? 0.5 : blocks.map(\.confidence).reduce(0, +) / Float(blocks.count)

        let result = OCRResult(fullText: fullText, blocks: blocks, confidence: avgConfidence)

        print("🔍 OCR completed: \(fullText.count) characters, \(blocks.count) blocks")
        return result
    }

    // MARK: - Local OCR Fallback (Apple Vision Framework)

    /// Uses Apple's built-in Vision framework for offline OCR (no API key needed).
    func performLocalOCR(imageData: Data) async throws -> String {
        guard let image = NSImage(data: imageData),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw VisionError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: VisionError.apiError(error.localizedDescription))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: VisionError.noTextDetected)
                    return
                }

                let text = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                continuation.resume(returning: text)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
