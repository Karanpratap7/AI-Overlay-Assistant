import SwiftUI

/// Main overlay content view — glassmorphic floating UI with chat, status badges,
/// and streaming response display.
struct OverlayContentView: View {
    @ObservedObject var viewModel: OverlayViewModel
    @State private var isHovering = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Title Bar
            titleBar

            if !viewModel.isCollapsed {
                // Chat Area
                chatArea

                // Streaming indicator
                if !viewModel.streamingText.isEmpty {
                    streamingView
                }

                if viewModel.isScreenRecordingError {
                    HStack(spacing: 6) {
                        Text("Screen Recording permission needed.")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.8))
                        Button("Open Settings") {
                            viewModel.openPermissionsSettings()
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.cyan)
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }

                Divider()
                    .background(Color.white.opacity(0.1))

                // Input Area
                inputArea
            }
        }
        .frame(width: 360, height: viewModel.isCollapsed ? 44 : 500)
        .background(glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .opacity(viewModel.opacity)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }

    // MARK: - Title Bar

    private var titleBar: some View {
        HStack(spacing: 8) {
            // Status badge
            Text(viewModel.statusBadge)
                .font(.system(size: 14))
                .animation(.easeInOut, value: viewModel.statusBadge)

            Text("AI Assistant")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)

            Spacer()

            // Status indicator
            statusIndicator

            // Collapse button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.isCollapsed.toggle()
                }
            }) {
                Image(systemName: viewModel.isCollapsed ? "chevron.down" : "chevron.up")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Close button
            Button(action: {
                viewModel.isVisible = false
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 20, height: 20)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.05))
    }

    // MARK: - Status Indicator

    private var statusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
                .scaleEffect(isPulsing ? 1.3 : 1.0)
                .animation(
                    isPulsing ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default,
                    value: isPulsing
                )

            Text(statusText)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private var statusColor: Color {
        switch viewModel.appState {
        case .idle: return .green
        case .capturing: return .blue
        case .processing: return .orange
        case .thinking: return .purple
        case .streaming: return .cyan
        case .error: return .red
        }
    }

    private var statusText: String {
        switch viewModel.appState {
        case .idle: return "Ready"
        case .capturing: return "Capturing"
        case .processing: return "Processing"
        case .thinking: return "Thinking"
        case .streaming: return "Streaming"
        case .error(let msg): return msg
        }
    }

    private var isPulsing: Bool {
        switch viewModel.appState {
        case .thinking, .streaming, .capturing, .processing: return true
        default: return false
        }
    }

    // MARK: - Chat Area

    private var chatArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if viewModel.messages.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: viewModel.messages.count) { _ in
                if let lastMessage = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.3))

            Text("Ready to assist")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.4))

            VStack(alignment: .leading, spacing: 6) {
                shortcutHint("⌘⇧Space", "Toggle overlay")
                shortcutHint("⌘⇧C", "Capture screen")
                shortcutHint("⌘⇧A", "Toggle audio")
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func shortcutHint(_ keys: String, _ description: String) -> some View {
        HStack(spacing: 6) {
            Text(keys)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.cyan.opacity(0.8))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.08))
                .cornerRadius(4)

            Text(description)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.4))
        }
    }

    // MARK: - Streaming View

    private var streamingView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                    .foregroundColor(.cyan)
                Text("Responding...")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.cyan.opacity(0.8))
                Spacer()
            }
            .padding(.horizontal, 12)

            Text(viewModel.streamingText)
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
        .background(Color.white.opacity(0.03))
        .transition(.opacity)
    }

    // MARK: - Input Area

    private var inputArea: some View {
        HStack(spacing: 8) {
            // Audio toggle
            Button(action: { viewModel.toggleAudioCapture() }) {
                Image(systemName: viewModel.isListening ? "mic.fill" : "mic")
                    .font(.system(size: 14))
                    .foregroundColor(viewModel.isListening ? .red : .white.opacity(0.5))
                    .frame(width: 28, height: 28)
                    .background(viewModel.isListening ? Color.red.opacity(0.2) : Color.white.opacity(0.05))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            // Screen capture button
            Button(action: { viewModel.captureAndAnalyze() }) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.05))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            // Text input
            TextField("Ask anything...", text: $viewModel.userInput)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .focused($isInputFocused)
                .onSubmit { viewModel.sendMessage() }

            // Send button
            Button(action: { viewModel.sendMessage() }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(viewModel.userInput.isEmpty ? .white.opacity(0.2) : .cyan)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.userInput.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Glass Background

    private var glassBackground: some View {
        ZStack {
            // Dark translucent base
            Color.black.opacity(0.75)

            // Vibrancy effect
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)

            // Gradient overlay for depth
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.08),
                    Color.clear,
                    Color.white.opacity(0.03)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: OverlayViewModel.ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == "assistant" {
                // AI avatar
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundColor(.cyan)
                    .frame(width: 24, height: 24)
                    .background(Color.cyan.opacity(0.15))
                    .clipShape(Circle())
            }

            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        message.role == "user"
                        ? Color.cyan.opacity(0.2)
                        : Color.white.opacity(0.08)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                if let source = message.source {
                    HStack(spacing: 4) {
                        Image(systemName: sourceIcon(source))
                            .font(.system(size: 8))
                        Text(source)
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.white.opacity(0.3))
                }
            }
            .frame(maxWidth: .infinity, alignment: message.role == "user" ? .trailing : .leading)

            if message.role == "user" {
                // User avatar
                Image(systemName: "person.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
        }
    }

    private func sourceIcon(_ source: String) -> String {
        switch source {
        case "screen": return "display"
        case "audio": return "waveform"
        case "memory": return "brain"
        default: return "globe"
        }
    }
}

// MARK: - Visual Effect View (NSVisualEffectView wrapper)

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
