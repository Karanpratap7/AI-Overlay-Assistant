import SwiftUI

/// Settings view for API key configuration and app preferences.
/// Accessible via the menu bar or macOS Settings menu.
struct SettingsView: View {
    // MARK: - State

    @State private var openAIKey = ""
    @State private var anthropicKey = ""
    @State private var geminiKey = ""
    @State private var googleVisionKey = ""

    @State private var selectedProvider: LLMService.Provider = .openai
    @State private var selectedModel = "gpt-4o"
    @State private var overlayOpacity: Double = 0.85
    @State private var showSaveConfirmation = false

    @State private var keysConfigured: [KeychainService.KeyIdentifier: Bool] = [:]

    private let keychain = KeychainService.shared

    // MARK: - Body

    var body: some View {
        TabView {
            apiKeysTab
                .tabItem {
                    Label("API Keys", systemImage: "key.fill")
                }

            modelTab
                .tabItem {
                    Label("Model", systemImage: "cpu")
                }

            appearanceTab
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 520, height: 420)
        .onAppear(perform: loadKeyStatus)
    }

    // MARK: - API Keys Tab

    private var apiKeysTab: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label("OpenAI API Key", systemImage: "key")
                        Spacer()
                        keyStatusBadge(.openAIKey)
                    }
                    SecureField("sk-...", text: $openAIKey)
                        .textFieldStyle(.roundedBorder)
                    Text("Used for GPT-4o and Whisper transcription")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label("Anthropic API Key", systemImage: "key")
                        Spacer()
                        keyStatusBadge(.anthropicKey)
                    }
                    SecureField("sk-ant-...", text: $anthropicKey)
                        .textFieldStyle(.roundedBorder)
                    Text("Used for Claude models")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label("Google Gemini API Key", systemImage: "key")
                        Spacer()
                        keyStatusBadge(.geminiKey)
                    }
                    SecureField("AIza...", text: $geminiKey)
                        .textFieldStyle(.roundedBorder)
                    Text("Used for Gemini models")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label("Google Vision API Key", systemImage: "key")
                        Spacer()
                        keyStatusBadge(.googleVisionKey)
                    }
                    SecureField("AIza...", text: $googleVisionKey)
                        .textFieldStyle(.roundedBorder)
                    Text("Used for screen OCR (optional — falls back to Apple Vision)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section {
                HStack {
                    Button("Save All Keys") {
                        saveKeys()
                    }
                    .buttonStyle(.borderedProminent)

                    if showSaveConfirmation {
                        Text("✅ Saved to Keychain")
                            .font(.caption)
                            .foregroundColor(.green)
                            .transition(.opacity)
                    }

                    Spacer()

                    Button("Clear All Keys", role: .destructive) {
                        keychain.clearAll()
                        clearFields()
                        loadKeyStatus()
                    }
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Security", systemImage: "lock.shield")
                        .font(.headline)
                    Text("All API keys are stored exclusively in the macOS Keychain — never written to files on disk. Keys are accessible only to this application and are protected by your macOS login password.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }

    // MARK: - Model Tab

    private var modelTab: some View {
        Form {
            Section("LLM Provider") {
                Picker("Provider", selection: $selectedProvider) {
                    ForEach(LLMService.Provider.allCases) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .pickerStyle(.segmented)

                TextField("Model ID", text: $selectedModel)
                    .textFieldStyle(.roundedBorder)

                Text("Default: \(selectedProvider.defaultModel)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Available Models") {
                modelList
            }
        }
        .padding()
        .onChange(of: selectedProvider) { newValue in
            selectedModel = newValue.defaultModel
        }
    }

    private var modelList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                modelRow("GPT-4o", "Fast, multimodal, vision-capable", .openai)
                modelRow("GPT-4 Turbo", "High capability, lower cost", .openai)
                modelRow("claude-sonnet-4-20250514", "Excellent reasoning, long context", .anthropic)
                modelRow("Gemini 2.0 Flash", "Fast, free tier available", .gemini)
            }
        }
    }

    private func modelRow(_ name: String, _ desc: String, _ provider: LLMService.Provider) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(name).font(.system(size: 13, weight: .medium))
                Text(desc).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Text(provider.rawValue)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(4)
        }
    }

    // MARK: - Appearance Tab

    private var appearanceTab: some View {
        Form {
            Section("Overlay") {
                Slider(value: $overlayOpacity, in: 0.4...1.0, step: 0.05) {
                    Text("Opacity: \(Int(overlayOpacity * 100))%")
                }
            }

            Section("Shortcuts") {
                shortcutRow("Toggle Overlay", "⌘ ⇧ Space")
                shortcutRow("Capture Screen", "⌘ ⇧ C")
                shortcutRow("Toggle Audio", "⌘ ⇧ A")
                shortcutRow("Hide Overlay", "Escape")
            }
        }
        .padding()
    }

    private func shortcutRow(_ action: String, _ shortcut: String) -> some View {
        HStack {
            Text(action)
            Spacer()
            Text(shortcut)
                .font(.system(size: 12, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
        }
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("AI Overlay Assistant")
                .font(.title2.bold())

            Text("Version 1.0.0")
                .foregroundColor(.secondary)

            Text("A native macOS AI assistant that captures screen content, transcribes audio, and uses LLM APIs to generate answers — all displayed in a translucent floating overlay that is invisible to screen sharing tools.")
                .multilineTextAlignment(.center)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)

            Divider()

            VStack(spacing: 4) {
                Text("Built with ❤️ using Swift + SwiftUI")
                    .font(.caption)
                Text("Stealth powered by NSWindow.sharingType = .none")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    // MARK: - Helpers

    private func keyStatusBadge(_ key: KeychainService.KeyIdentifier) -> some View {
        Group {
            if keysConfigured[key] == true {
                Label("Configured", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            } else {
                Label("Not Set", systemImage: "xmark.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func loadKeyStatus() {
        keysConfigured = keychain.configuredKeys()
    }

    private func saveKeys() {
        if !openAIKey.isEmpty {
            keychain.save(key: .openAIKey, value: openAIKey)
        }
        if !anthropicKey.isEmpty {
            keychain.save(key: .anthropicKey, value: anthropicKey)
        }
        if !geminiKey.isEmpty {
            keychain.save(key: .geminiKey, value: geminiKey)
        }
        if !googleVisionKey.isEmpty {
            keychain.save(key: .googleVisionKey, value: googleVisionKey)
        }

        loadKeyStatus()

        withAnimation {
            showSaveConfirmation = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showSaveConfirmation = false
            }
        }

        clearFields()
    }

    private func clearFields() {
        openAIKey = ""
        anthropicKey = ""
        geminiKey = ""
        googleVisionKey = ""
    }
}
