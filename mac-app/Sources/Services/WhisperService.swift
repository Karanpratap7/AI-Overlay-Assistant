import Foundation

/// Whisper transcription service — supports OpenAI Whisper API (cloud)
/// and can be extended for local whisper.cpp integration.
final class WhisperService: ObservableObject {

    // MARK: - Types

    enum TranscriptionMode {
        case cloud  // OpenAI Whisper API
        case local  // whisper.cpp (future)
    }

    enum WhisperError: Error, LocalizedError {
        case noAPIKey
        case invalidAudio
        case apiError(String)
        case transcriptionFailed

        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "OpenAI API key not configured for Whisper"
            case .invalidAudio: return "Invalid audio data"
            case .apiError(let msg): return "Whisper API error: \(msg)"
            case .transcriptionFailed: return "Transcription failed"
            }
        }
    }

    // MARK: - Published State

    @Published var isTranscribing = false
    @Published var lastTranscript: String?

    // MARK: - Properties

    var mode: TranscriptionMode = .cloud
    private let credentials = CredentialStore.shared

    // MARK: - Transcribe

    /// Transcribes audio data (WAV format) to text.
    func transcribe(audioData: Data) async throws -> String {
        switch mode {
        case .cloud:
            return try await transcribeCloud(audioData: audioData)
        case .local:
            return try await transcribeLocal(audioData: audioData)
        }
    }

    // MARK: - Cloud Transcription (OpenAI Whisper API)

    private func transcribeCloud(audioData: Data) async throws -> String {
        // Use OpenAI key for Whisper API (same provider)
        guard let apiKey = credentials.retrieve(key: .openAIKey) else {
            throw WhisperError.noAPIKey
        }

        await MainActor.run { self.isTranscribing = true }
        defer {
            Task { @MainActor in self.isTranscribing = false }
        }

        let url = URL(string: "https://api.openai.com/v1/audio/transcriptions")!

        // Build multipart form data
        let boundary = UUID().uuidString
        var body = Data()

        // Audio file part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // Model part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)

        // Response format
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("json".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)

        // Language (optional — auto-detect)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw WhisperError.apiError("HTTP \(statusCode)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["text"] as? String else {
            throw WhisperError.transcriptionFailed
        }

        await MainActor.run {
            self.lastTranscript = text
        }

        print("🗣️ Transcription: \(text.prefix(100))...")
        return text
    }

    // MARK: - Local Transcription (whisper.cpp — future)

    private func transcribeLocal(audioData: Data) async throws -> String {
        // TODO: Integrate whisper.cpp for local, private transcription
        // This would use the whisper.cpp Swift bindings or a local Python service
        throw WhisperError.apiError("Local transcription not yet implemented. Use cloud mode.")
    }
}
