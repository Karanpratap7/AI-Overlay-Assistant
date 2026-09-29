import Foundation
import FoundationModels

/// Multi-provider LLM service supporting on-device Apple Intelligence plus
/// OpenAI, Anthropic (Claude), and Google Gemini.
/// Uses streaming for real-time token delivery to the overlay UI.
final class LLMService: ObservableObject {

    // MARK: - Types

    enum Provider: String, CaseIterable, Identifiable {
        case appleAI = "Apple Intelligence"
        case openai = "OpenAI"
        case anthropic = "Anthropic"
        case gemini = "Gemini"

        var id: String { rawValue }

        var defaultModel: String {
            switch self {
            case .appleAI: return "Apple Intelligence"
            case .openai: return "gpt-4o"
            case .anthropic: return "claude-sonnet-4-20250514"
            case .gemini: return "gemini-2.0-flash"
            }
        }

        /// The credential key required by this provider, or nil for providers
        /// that need no API key (Apple Intelligence is fully on-device).
        var credentialsKey: CredentialStore.KeyIdentifier? {
            switch self {
            case .appleAI: return nil
            case .openai: return .openAIKey
            case .anthropic: return .anthropicKey
            case .gemini: return .geminiKey
            }
        }
    }

    enum LLMError: Error, LocalizedError {
        case noAPIKey
        case invalidResponse
        case networkError(String)
        case rateLimited
        case tokenBudgetExceeded
        case appleIntelligenceUnavailable

        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "No API key configured"
            case .invalidResponse: return "Invalid response from API"
            case .networkError(let msg): return "Network error: \(msg)"
            case .rateLimited: return "Rate limited — please wait"
            case .tokenBudgetExceeded: return "Token budget exceeded for this session"
            case .appleIntelligenceUnavailable:
                return "Apple Intelligence is unavailable on this device. Enable it in System Settings or choose another provider."
            }
        }
    }

    // MARK: - Published State

    @Published var isStreaming = false
    @Published var currentResponse = ""
    @Published var error: String?

    // MARK: - Properties

    var selectedProvider: Provider = .appleAI
    var selectedModel: String = "Apple Intelligence"

    private let credentials = CredentialStore.shared
    private var lastRequestTime: Date?
    private let cooldownInterval: TimeInterval = 2.5
    private var sessionTokenCount: Int = 0
    private var tokenBudget: Int = 100_000 // Configurable

    // MARK: - Streaming Request

    /// Sends a streaming request to the selected LLM provider.
    func streamRequest(
        systemPrompt: String,
        messages: [[String: String]],
        onToken: @escaping (String) -> Void,
        onComplete: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        // Rate limiting
        if let lastTime = lastRequestTime,
           Date().timeIntervalSince(lastTime) < cooldownInterval {
            onError(LLMError.rateLimited)
            return
        }

        lastRequestTime = Date()

        // Apple Intelligence runs fully on-device and needs no API key.
        if selectedProvider == .appleAI {
            Task {
                await MainActor.run {
                    self.isStreaming = true
                    self.currentResponse = ""
                    self.error = nil
                }

                do {
                    try await streamAppleIntelligence(systemPrompt: systemPrompt, messages: messages, onToken: onToken, onComplete: onComplete)
                } catch {
                    await MainActor.run {
                        self.isStreaming = false
                        self.error = error.localizedDescription
                    }
                    onError(error)
                }
            }
            return
        }

        guard let keyIdentifier = selectedProvider.credentialsKey,
              let apiKey = credentials.retrieve(key: keyIdentifier) else {
            onError(LLMError.noAPIKey)
            return
        }

        Task {
            await MainActor.run {
                self.isStreaming = true
                self.currentResponse = ""
                self.error = nil
            }

            do {
                switch selectedProvider {
                case .appleAI:
                    break
                case .openai:
                    try await streamOpenAI(apiKey: apiKey, systemPrompt: systemPrompt, messages: messages, onToken: onToken, onComplete: onComplete)
                case .anthropic:
                    try await streamAnthropic(apiKey: apiKey, systemPrompt: systemPrompt, messages: messages, onToken: onToken, onComplete: onComplete)
                case .gemini:
                    try await streamGemini(apiKey: apiKey, systemPrompt: systemPrompt, messages: messages, onToken: onToken, onComplete: onComplete)
                }
            } catch {
                await MainActor.run {
                    self.isStreaming = false
                    self.error = error.localizedDescription
                }
                onError(error)
            }
        }
    }

    // MARK: - Apple Intelligence Streaming

    /// Streams a response from the on-device Apple Intelligence model via the
    /// Foundation Models framework. Requires no API key.
    private func streamAppleIntelligence(
        systemPrompt: String,
        messages: [[String: String]],
        onToken: @escaping (String) -> Void,
        onComplete: @escaping (String) -> Void
    ) async throws {
        guard #available(macOS 26, *) else {
            throw LLMError.appleIntelligenceUnavailable
        }

        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            throw LLMError.appleIntelligenceUnavailable
        }

        // Flatten system + conversation history into a single prompt.
        var transcript = ""
        for msg in messages {
            let role = msg["role"] == "assistant" ? "Assistant" : "User"
            transcript += "\(role): \(msg["content"] ?? "")\n"
        }
        let prompt = transcript.trimmingCharacters(in: .whitespacesAndNewlines)

        let session = LanguageModelSession(model: model, instructions: systemPrompt)
        let stream = session.streamResponse(to: prompt)

        var fullResponse = ""
        var previous = ""

        for try await snapshot in stream {
            let piece = snapshot.content
            guard piece.count > previous.count else { continue }
            let delta = String(piece.dropFirst(previous.count))
            previous = piece
            fullResponse = piece
            await MainActor.run {
                self.currentResponse = piece
                onToken(delta)
            }
        }

        await MainActor.run {
            self.isStreaming = false
            self.currentResponse = fullResponse
            onComplete(fullResponse)
        }
    }

    // MARK: - OpenAI Streaming

    private func streamOpenAI(
        apiKey: String,
        systemPrompt: String,
        messages: [[String: String]],
        onToken: @escaping (String) -> Void,
        onComplete: @escaping (String) -> Void
    ) async throws {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!

        var allMessages: [[String: String]] = [["role": "system", "content": systemPrompt]]
        allMessages.append(contentsOf: messages)

        let body: [String: Any] = [
            "model": selectedModel,
            "messages": allMessages,
            "stream": true,
            "max_tokens": 1024,
            "temperature": 0.7
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        try await performSSEStream(request: request, parser: parseOpenAISSE, onToken: onToken, onComplete: onComplete)
    }

    // MARK: - Anthropic Streaming

    private func streamAnthropic(
        apiKey: String,
        systemPrompt: String,
        messages: [[String: String]],
        onToken: @escaping (String) -> Void,
        onComplete: @escaping (String) -> Void
    ) async throws {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!

        let body: [String: Any] = [
            "model": selectedModel,
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": messages,
            "stream": true
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        try await performSSEStream(request: request, parser: parseAnthropicSSE, onToken: onToken, onComplete: onComplete)
    }

    // MARK: - Gemini Streaming

    private func streamGemini(
        apiKey: String,
        systemPrompt: String,
        messages: [[String: String]],
        onToken: @escaping (String) -> Void,
        onComplete: @escaping (String) -> Void
    ) async throws {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(selectedModel):streamGenerateContent?key=\(apiKey)&alt=sse")!

        // Convert chat messages to Gemini format
        var contents: [[String: Any]] = []
        for msg in messages {
            let role = msg["role"] == "assistant" ? "model" : "user"
            contents.append([
                "role": role,
                "parts": [["text": msg["content"] ?? ""]]
            ])
        }

        let body: [String: Any] = [
            "contents": contents,
            "systemInstruction": [
                "parts": [["text": systemPrompt]]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "maxOutputTokens": 1024
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        try await performSSEStream(request: request, parser: parseGeminiSSE, onToken: onToken, onComplete: onComplete)
    }

    // MARK: - SSE Stream Engine

    private func performSSEStream(
        request: URLRequest,
        parser: @escaping (String) -> String?,
        onToken: @escaping (String) -> Void,
        onComplete: @escaping (String) -> Void
    ) async throws {
        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw LLMError.networkError("HTTP \(httpResponse.statusCode)")
        }

        var fullResponse = ""

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let data = String(line.dropFirst(6))

            if data == "[DONE]" { break }

            if let token = parser(data) {
                fullResponse += token
                await MainActor.run {
                    self.currentResponse = fullResponse
                    onToken(token)
                }
            }
        }

        await MainActor.run {
            self.isStreaming = false
            self.currentResponse = fullResponse
            onComplete(fullResponse)
        }
    }

    // MARK: - SSE Parsers

    private func parseOpenAISSE(_ data: String) -> String? {
        guard let jsonData = data.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let delta = choices.first?["delta"] as? [String: Any],
              let content = delta["content"] as? String else {
            return nil
        }
        return content
    }

    private func parseAnthropicSSE(_ data: String) -> String? {
        guard let jsonData = data.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }

        let type = json["type"] as? String
        if type == "content_block_delta",
           let delta = json["delta"] as? [String: Any],
           let text = delta["text"] as? String {
            return text
        }
        return nil
    }

    private func parseGeminiSSE(_ data: String) -> String? {
        guard let jsonData = data.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            return nil
        }
        return text
    }

    // MARK: - Vision Request (for screenshot-to-LLM)

    /// Sends a screenshot directly to a vision-capable LLM.
    func visionRequest(
        imageBase64: String,
        prompt: String,
        onToken: @escaping (String) -> Void,
        onComplete: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        guard let keyIdentifier = selectedProvider.credentialsKey,
              let apiKey = credentials.retrieve(key: keyIdentifier) else {
            onError(LLMError.noAPIKey)
            return
        }

        Task {
            await MainActor.run {
                self.isStreaming = true
                self.currentResponse = ""
            }

            do {
                let url = URL(string: "https://api.openai.com/v1/chat/completions")!

                let body: [String: Any] = [
                    "model": "gpt-4o",
                    "messages": [
                        [
                            "role": "user",
                            "content": [
                                ["type": "text", "text": prompt],
                                [
                                    "type": "image_url",
                                    "image_url": ["url": "data:image/jpeg;base64,\(imageBase64)"]
                                ]
                            ]
                        ]
                    ],
                    "stream": true,
                    "max_tokens": 1024
                ]

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: body)

                try await performSSEStream(request: request, parser: parseOpenAISSE, onToken: onToken, onComplete: onComplete)
            } catch {
                await MainActor.run {
                    self.isStreaming = false
                    self.error = error.localizedDescription
                }
                onError(error)
            }
        }
    }
}
