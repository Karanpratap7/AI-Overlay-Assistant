import Foundation
import SwiftUI
import Combine

/// Main view model for the overlay — orchestrates capture, transcription, LLM calls,
/// and manages all UI state.
@MainActor
final class OverlayViewModel: ObservableObject {

    // MARK: - Types

    enum AppState {
        case idle
        case capturing
        case processing
        case thinking
        case streaming
        case error(String)
    }

    struct ChatMessage: Identifiable {
        let id = UUID()
        let role: String   // "user" or "assistant"
        let content: String
        let source: String? // "screen", "audio", "memory", "general knowledge"
        let timestamp: Date
    }

    // MARK: - Published State

    @Published var appState: AppState = .idle
    @Published var isVisible = false
    @Published var isCollapsed = false
    @Published var userInput = ""
    @Published var messages: [ChatMessage] = []
    @Published var streamingText = ""
    @Published var opacity: Double = 0.85
    @Published var isListening = false
    @Published var statusBadge: String = "🔒"

    // Screen state
    @Published var screenText: String?
    @Published var audioTranscript: String?

    // MARK: - Dependencies

    private let llmService: LLMService
    private let visionService: VisionService
    private let whisperService: WhisperService
    private let audioCaptureManager: AudioCaptureManager
    private let screenCaptureManager: ScreenCaptureManager
    private let contextBuilder: ContextBuilder

    // MARK: - Init

    init(
        llmService: LLMService,
        visionService: VisionService,
        whisperService: WhisperService,
        audioCaptureManager: AudioCaptureManager,
        screenCaptureManager: ScreenCaptureManager,
        contextBuilder: ContextBuilder
    ) {
        self.llmService = llmService
        self.visionService = visionService
        self.whisperService = whisperService
        self.audioCaptureManager = audioCaptureManager
        self.screenCaptureManager = screenCaptureManager
        self.contextBuilder = contextBuilder

        setupAudioCallback()
    }

    // MARK: - Audio Callback

    private func setupAudioCallback() {
        audioCaptureManager.onAudioChunkReady = { [weak self] audioData in
            Task { @MainActor [weak self] in
                await self?.handleAudioChunk(audioData)
            }
        }
    }

    private func handleAudioChunk(_ audioData: Data) async {
        do {
            let transcript = try await whisperService.transcribe(audioData: audioData)
            self.audioTranscript = (self.audioTranscript ?? "") + " " + transcript
        } catch {
            print("❌ Transcription error: \(error.localizedDescription)")
        }
    }

    // MARK: - Actions

    /// Captures the screen and analyzes it with Vision API.
    func captureAndAnalyze() {
        Task {
            appState = .capturing
            statusBadge = "📸"

            // Request permission if needed
            await screenCaptureManager.checkPermission()

            guard let image = await screenCaptureManager.captureRegion() else {
                if screenCaptureManager.hasPermission == false {
                    appState = .error("Screen Recording permission required")
                    print("❌ Screen capture failed: Screen Recording permission not granted")
                } else {
                    appState = .error("Screen capture failed")
                }
                statusBadge = "🔒"
                return
            }

            appState = .processing
            statusBadge = "🔍"

            // Convert to base64 for API
            guard let base64 = screenCaptureManager.imageToBase64(image) else {
                appState = .error("Image conversion failed")
                statusBadge = "🔒"
                return
            }

            // Perform OCR
            do {
                let result = try await visionService.performOCR(imageBase64: base64)
                self.screenText = result.fullText
                print("📝 Screen text extracted: \(result.fullText.prefix(200))...")
            } catch {
                print("⚠️ OCR failed, will use direct vision: \(error.localizedDescription)")
                // Fall through — we can still use vision LLM directly
            }

            appState = .idle
            statusBadge = "🔒"

            // Auto-send if there's pending user input
            if !userInput.isEmpty {
                sendMessage()
            }
        }
    }

    /// Sends the current user input to the LLM.
    func sendMessage() {
        let input = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        // Add user message
        let userMessage = ChatMessage(
            role: "user",
            content: input,
            source: nil,
            timestamp: Date()
        )
        messages.append(userMessage)
        userInput = ""

        appState = .thinking
        statusBadge = "⚡"
        streamingText = ""

        // Build context
        let (systemPrompt, contextMessages) = contextBuilder.buildPrompt(
            screenText: screenText,
            audioTranscript: audioTranscript,
            userInput: input
        )

        // Stream LLM response
        llmService.streamRequest(
            systemPrompt: systemPrompt,
            messages: contextMessages,
            onToken: { [weak self] token in
                Task { @MainActor in
                    self?.appState = .streaming
                    self?.statusBadge = "⚡"
                    self?.streamingText += token
                }
            },
            onComplete: { [weak self] fullResponse in
                Task { @MainActor in
                    guard let self = self else { return }

                    let assistantMessage = ChatMessage(
                        role: "assistant",
                        content: fullResponse,
                        source: self.screenText != nil ? "screen" : "general knowledge",
                        timestamp: Date()
                    )
                    self.messages.append(assistantMessage)
                    self.streamingText = ""
                    self.appState = .idle
                    self.statusBadge = "🔒"

                    // Update context memory
                    self.contextBuilder.addExchange(userMessage: input, assistantResponse: fullResponse)
                }
            },
            onError: { [weak self] error in
                Task { @MainActor in
                    self?.appState = .error(error.localizedDescription)
                    self?.statusBadge = "❌"
                }
            }
        )
    }

    /// True when the current error is a missing Screen Recording permission.
    var isScreenRecordingError: Bool {
        if case .error(let message) = appState {
            return message.hasPrefix("Screen Recording")
        }
        return false
    }

    /// Opens System Settings to the Screen & System Audio Recording pane.
    func openPermissionsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Toggles audio capture on/off.
    func toggleAudioCapture() {
        if audioCaptureManager.isCapturing {
            audioCaptureManager.stopCapture()
            isListening = false
            statusBadge = "🔒"
        } else {
            audioCaptureManager.startCapture()
            isListening = true
            statusBadge = "🎤"
        }
    }

    /// Clears chat history.
    func clearChat() {
        messages.removeAll()
        streamingText = ""
        screenText = nil
        audioTranscript = nil
        contextBuilder.clearHistory()
        appState = .idle
    }

    /// Updates the selected LLM provider and model.
    func setProvider(_ provider: LLMService.Provider) {
        llmService.selectedProvider = provider
        llmService.selectedModel = provider.defaultModel
    }

    func setModel(_ model: String) {
        llmService.selectedModel = model
    }
}
