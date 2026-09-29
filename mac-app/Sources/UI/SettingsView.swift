import SwiftUI
import Carbon

/// Settings view for API key configuration, hotkey customization, and app preferences.
struct SettingsView: View {
    // MARK: - State

    @State private var openAIKey = ""
    @State private var anthropicKey = ""
    @State private var geminiKey = ""

    @State private var selectedProvider: LLMService.Provider = .appleAI
    @State private var selectedModel = "Apple Intelligence"
    @State private var overlayOpacity: Double = 0.85
    @State private var showSaveConfirmation = false

    @State private var keysConfigured: [CredentialStore.KeyIdentifier: Bool] = [:]

    @ObservedObject private var hotkeySettings = HotkeySettings.shared

    private let credentials = CredentialStore.shared

    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                apiKeysTab
                    .tabItem {
                        Label("API Keys", systemImage: "key.fill")
                    }

                shortcutsTab
                    .tabItem {
                        Label("Shortcuts", systemImage: "keyboard")
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
            
            Divider()
            
            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
        }
        .frame(width: 540, height: 500)
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
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Label("On-device Models", systemImage: "brain")
                        .font(.headline)
                    Text("OCR and Apple Intelligence run entirely on-device — no API key required. Optional keys above unlock cloud models.")
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
                        Text("✅ Saved")
                            .font(.caption)
                            .foregroundColor(.green)
                            .transition(.opacity)
                    }

                    Spacer()

                    Button("Clear All Keys", role: .destructive) {
                        credentials.clearAll()
                        clearFields()
                        loadKeyStatus()
                    }
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Security", systemImage: "lock.shield")
                        .font(.headline)
                    Text("API keys are stored in a local file in ~/Library/Application Support/AIOverlayAssistant — readable only by your user account. No keychain access is used.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }

    // MARK: - Shortcuts Tab

    private var shortcutsTab: some View {
        Form {
            Section("Keyboard Shortcuts") {
                Text("Click on a shortcut field, then press the key combination you want to use.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ShortcutRecorderRow(
                    label: "Toggle Overlay",
                    shortcut: $hotkeySettings.toggleOverlay
                )

                ShortcutRecorderRow(
                    label: "Capture Screen",
                    shortcut: $hotkeySettings.captureRegion
                )

                ShortcutRecorderRow(
                    label: "Toggle Audio",
                    shortcut: $hotkeySettings.toggleAudio
                )

                ShortcutRecorderRow(
                    label: "Hide Overlay",
                    shortcut: $hotkeySettings.hideOverlay
                )
            }

            Section {
                HStack {
                    Button("Save Shortcuts") {
                        hotkeySettings.save()
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()

                    Button("Reset to Defaults") {
                        hotkeySettings.resetToDefaults()
                    }
                }
            }

            Section("Default Shortcuts") {
                VStack(alignment: .leading, spacing: 6) {
                    defaultRow("Toggle Overlay", "⌘⇧Space")
                    defaultRow("Capture Screen", "⌘⇧C")
                    defaultRow("Toggle Audio", "⌘⇧A")
                    defaultRow("Hide Overlay", "Escape")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    private func defaultRow(_ action: String, _ shortcut: String) -> some View {
        HStack {
            Text(action)
            Spacer()
            Text(shortcut)
                .font(.system(.caption, design: .monospaced))
        }
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
                modelRow("Apple Intelligence", "On-device, no API key", .appleAI)
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
        }
        .padding()
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

    private func keyStatusBadge(_ key: CredentialStore.KeyIdentifier) -> some View {
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
        keysConfigured = credentials.configuredKeys()
    }

    private func saveKeys() {
        if !openAIKey.isEmpty {
            credentials.save(key: .openAIKey, value: openAIKey)
        }
        if !anthropicKey.isEmpty {
            credentials.save(key: .anthropicKey, value: anthropicKey)
        }
        if !geminiKey.isEmpty {
            credentials.save(key: .geminiKey, value: geminiKey)
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
    }
}

// MARK: - Shortcut Recorder Row

/// A row that captures key presses to record a new shortcut.
struct ShortcutRecorderRow: View {
    let label: String
    @Binding var shortcut: HotkeySettings.Shortcut
    @State private var isRecording = false

    var body: some View {
        HStack {
            Text(label)

            Spacer()

            if isRecording {
                Text("Press shortcut…")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.orange.opacity(0.4), lineWidth: 1)
                    )
            } else {
                Button(action: { isRecording = true }) {
                    Text(shortcut.displayString)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.cyan.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            // Invisible key catcher when recording
            Group {
                if isRecording {
                    KeyRecorderView { keyCode, modifiers in
                        shortcut = HotkeySettings.Shortcut(
                            keyCode: UInt32(keyCode),
                            modifiers: modifiers.rawValue
                        )
                        isRecording = false
                    }
                    .frame(width: 0, height: 0)
                }
            }
        )
    }
}

// MARK: - Key Recorder (NSViewRepresentable)

/// An invisible NSView that captures the next key press for shortcut recording.
struct KeyRecorderView: NSViewRepresentable {
    let onKeyRecorded: (_ keyCode: UInt16, _ modifiers: NSEvent.ModifierFlags) -> Void

    func makeNSView(context: Context) -> KeyRecorderNSView {
        let view = KeyRecorderNSView()
        view.onKeyRecorded = onKeyRecorded
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: KeyRecorderNSView, context: Context) {
        nsView.onKeyRecorded = onKeyRecorded
    }
}

class KeyRecorderNSView: NSView {
    var onKeyRecorded: ((_ keyCode: UInt16, _ modifiers: NSEvent.ModifierFlags) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        onKeyRecorded?(event.keyCode, modifiers)
    }
}
