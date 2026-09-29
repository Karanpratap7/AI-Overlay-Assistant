import SwiftUI

/// Main application window — dashboard showing status, quick actions, and configuration.
struct MainWindowView: View {
    @ObservedObject var viewModel: OverlayViewModel
    @ObservedObject var hotkeySettings = HotkeySettings.shared
    @State private var showingSettings = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.06, blue: 0.12),
                    Color(red: 0.08, green: 0.04, blue: 0.16),
                    Color(red: 0.04, green: 0.08, blue: 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerSection

                ScrollView {
                    VStack(spacing: 20) {
                        // Status Card
                        statusCard

                        // Quick Actions
                        quickActionsCard

                        // Shortcuts Reference
                        shortcutsCard

                        // API Keys Status
                        apiKeysCard
                    }
                    .padding(24)
                }
            }
        }
        .frame(minWidth: 580, minHeight: 560)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .frame(minWidth: 540, minHeight: 440)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.cyan, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("AI Overlay Assistant")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Stealth AI Assistant for macOS")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()

            // Settings button
            Button(action: { showingSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.03))
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(spacing: 16) {
            HStack {
                Label("Status", systemImage: "circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(overlayStatusColor)
                        .frame(width: 8, height: 8)
                    Text(overlayStatusText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            HStack(spacing: 16) {
                statusBadge(
                    icon: "eye.fill",
                    label: "Overlay",
                    value: viewModel.isVisible ? "Visible" : "Hidden",
                    color: viewModel.isVisible ? .cyan : .gray
                )

                statusBadge(
                    icon: "mic.fill",
                    label: "Audio",
                    value: viewModel.isListening ? "Listening" : "Off",
                    color: viewModel.isListening ? .red : .gray
                )

                statusBadge(
                    icon: "lock.shield.fill",
                    label: "Stealth",
                    value: "Active",
                    color: .green
                )
            }

            if viewModel.isScreenRecordingError {
                HStack(spacing: 8) {
                    Text("Screen capture needs Screen Recording permission.")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)

                    Spacer()

                    Button("Fix In Settings") {
                        viewModel.openPermissionsSettings()
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.cyan)
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.cyan.opacity(0.1))
                    .clipShape(Capsule())
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func statusBadge(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.5))

            Text(value)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Quick Actions

    private var quickActionsCard: some View {
        VStack(spacing: 12) {
            HStack {
                Label("Quick Actions", systemImage: "bolt.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }

            HStack(spacing: 12) {
                actionButton(
                    icon: "rectangle.on.rectangle",
                    label: "Toggle Overlay",
                    color: .cyan
                ) {
                    viewModel.isVisible.toggle()
                }

                actionButton(
                    icon: "camera.viewfinder",
                    label: "Capture Screen",
                    color: .purple
                ) {
                    viewModel.captureAndAnalyze()
                }

                actionButton(
                    icon: "mic.fill",
                    label: "Toggle Audio",
                    color: .orange
                ) {
                    viewModel.toggleAudioCapture()
                }

                actionButton(
                    icon: "trash",
                    label: "Clear Chat",
                    color: .red
                ) {
                    viewModel.clearChat()
                }
            }
        }
        .padding(20)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func actionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Shortcuts Card

    private var shortcutsCard: some View {
        VStack(spacing: 12) {
            HStack {
                Label("Keyboard Shortcuts", systemImage: "keyboard")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()

                Button("Configure...") {
                    showingSettings = true
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.cyan)
                .buttonStyle(.plain)
            }

            VStack(spacing: 8) {
                shortcutRow("Toggle Overlay", hotkeySettings.toggleOverlay.displayString)
                shortcutRow("Capture Screen", hotkeySettings.captureRegion.displayString)
                shortcutRow("Toggle Audio", hotkeySettings.toggleAudio.displayString)
                shortcutRow("Hide Overlay", hotkeySettings.hideOverlay.displayString)
            }
        }
        .padding(20)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func shortcutRow(_ action: String, _ shortcut: String) -> some View {
        HStack {
            Text(action)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(shortcut)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(.cyan.opacity(0.9))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.cyan.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }

    // MARK: - API Keys Card

    private var apiKeysCard: some View {
        VStack(spacing: 12) {
            HStack {
                Label("API Keys", systemImage: "key.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()

                Button("Manage...") {
                    showingSettings = true
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.cyan)
                .buttonStyle(.plain)
            }

            let credentials = CredentialStore.shared
            let keys = credentials.configuredKeys()

            VStack(spacing: 6) {
                apiKeyRow("OpenAI", configured: keys[.openAIKey] ?? false)
                apiKeyRow("Anthropic", configured: keys[.anthropicKey] ?? false)
                apiKeyRow("Gemini", configured: keys[.geminiKey] ?? false)
            }
        }
        .padding(20)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func apiKeyRow(_ name: String, configured: Bool) -> some View {
        HStack {
            Text(name)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: configured ? "checkmark.circle.fill" : "xmark.circle")
                    .font(.system(size: 12))
                Text(configured ? "Configured" : "Not Set")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(configured ? .green : .white.opacity(0.3))
        }
    }

    // MARK: - Helpers

    private var overlayStatusColor: Color {
        switch viewModel.appState {
        case .idle: return .green
        case .capturing, .processing: return .blue
        case .thinking, .streaming: return .purple
        case .error: return .red
        }
    }

    private var overlayStatusText: String {
        switch viewModel.appState {
        case .idle: return "Ready"
        case .capturing: return "Capturing..."
        case .processing: return "Processing..."
        case .thinking: return "Thinking..."
        case .streaming: return "Streaming..."
        case .error(let msg): return msg
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(0.05))
            .modifier(ElectricBorderModifier(cornerRadius: 14))
    }
}

// MARK: - Electric Border Modifier

/// Adds an animated "electric border" using a rotating angular gradient.
struct ElectricBorderModifier: ViewModifier {
    var cornerRadius: CGFloat
    @State private var rotation: Double = 0.0

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.08),
                                Color.white.opacity(0.08),
                                Color.cyan.opacity(0.8),
                                Color.purple.opacity(0.8),
                                Color.cyan.opacity(0.8),
                                Color.white.opacity(0.08),
                                Color.white.opacity(0.08)
                            ]),
                            center: .center,
                            angle: .degrees(rotation)
                        ),
                        lineWidth: 1.5
                    )
            )
            .onAppear {
                withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                    rotation = 360.0
                }
            }
    }
}
