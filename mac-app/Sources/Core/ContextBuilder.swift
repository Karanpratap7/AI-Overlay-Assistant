import Foundation

/// Builds the unified context payload from screen capture, audio transcript,
/// user input, and conversation memory for submission to the LLM.
final class ContextBuilder {

    // MARK: - Types

    struct ContextPayload {
        let screenText: String?
        let audioTranscript: String?
        let userInput: String
        let conversationHistory: [Message]
        let timestamp: String

        struct Message {
            let role: String
            let content: String
        }
    }

    // MARK: - Memory

    /// Conversation history — last 5 exchanges kept in memory (not persisted to disk).
    private(set) var conversationHistory: [(role: String, content: String)] = []
    private let maxHistorySize = 5

    // MARK: - Build Context

    /// Builds the system prompt and messages array for the LLM API.
    func buildPrompt(
        screenText: String?,
        audioTranscript: String?,
        userInput: String
    ) -> (systemPrompt: String, messages: [[String: String]]) {

        let systemPrompt = """
        You are a discreet AI assistant overlay running on macOS.

        CONTEXT:
        - Screen content: \(screenText ?? "No screen content captured")
        - Audio transcript: \(audioTranscript ?? "No audio transcript available")
        - Conversation history: \(conversationHistory.count) previous exchanges
        - Current timestamp: \(ISO8601DateFormatter().string(from: Date()))

        INSTRUCTIONS:
        1. Answer based primarily on screen content + audio
        2. Keep answers concise — 2–3 sentences max
        3. If the answer isn't visible on screen, say: "I cannot see that in the current screen."
        4. Never repeat the user's question back to them
        5. Do not mention that you are an AI unless directly asked
        6. Format code or commands in backticks

        OUTPUT FORMAT:
        Provide a direct, helpful answer. Be concise and precise.
        """

        var messages: [[String: String]] = []

        // Add conversation history
        for entry in conversationHistory {
            messages.append(["role": entry.role, "content": entry.content])
        }

        // Add current user message
        messages.append(["role": "user", "content": userInput])

        return (systemPrompt, messages)
    }

    // MARK: - Memory Management

    /// Adds an exchange to conversation history.
    func addExchange(userMessage: String, assistantResponse: String) {
        conversationHistory.append((role: "user", content: userMessage))
        conversationHistory.append((role: "assistant", content: assistantResponse))

        // Trim to last 5 exchanges (10 messages)
        while conversationHistory.count > maxHistorySize * 2 {
            conversationHistory.removeFirst()
        }
    }

    /// Clears conversation history.
    func clearHistory() {
        conversationHistory.removeAll()
        print("🧹 Conversation history cleared")
    }

    /// Returns the conversation history as JSON-compatible array.
    func historyAsJSON() -> [[String: String]] {
        return conversationHistory.map { ["role": $0.role, "content": $0.content] }
    }
}
