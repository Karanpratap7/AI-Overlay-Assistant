import Cocoa
import SwiftUI
import ScreenCaptureKit

/// Main application delegate — manages lifecycle, permissions, overlay panel, and status bar.
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var overlayPanel: OverlayPanel?
    private var overlayViewModel: OverlayViewModel!
    private var hotkeyManager: HotkeyManager!
    private var stealthManager: StealthManager!
    private var screenCaptureManager: ScreenCaptureManager!
    private var audioCaptureManager: AudioCaptureManager!
    private var contextBuilder: ContextBuilder!
    private var llmService: LLMService!
    private var visionService: VisionService!
    private var whisperService: WhisperService!

    private var statusItem: NSStatusItem?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize services
        stealthManager = StealthManager()
        llmService = LLMService()
        visionService = VisionService()
        whisperService = WhisperService()
        audioCaptureManager = AudioCaptureManager()
        screenCaptureManager = ScreenCaptureManager()
        contextBuilder = ContextBuilder()

        // Initialize view model with dependencies
        overlayViewModel = OverlayViewModel(
            llmService: llmService,
            visionService: visionService,
            whisperService: whisperService,
            audioCaptureManager: audioCaptureManager,
            screenCaptureManager: screenCaptureManager,
            contextBuilder: contextBuilder
        )

        // Create overlay panel
        setupOverlayPanel()

        // Setup global hotkeys
        setupHotkeys()

        // Setup status bar icon
        setupStatusBar()

        // Request permissions lazily
        requestPermissionsIfNeeded()

        // Apply stealth
        stealthManager.applyStealthToWindow(overlayPanel)

        print("✅ AI Overlay Assistant launched successfully")
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager?.unregisterAll()
        audioCaptureManager?.stopCapture()
    }

    // MARK: - Setup

    private func setupOverlayPanel() {
        let contentView = OverlayContentView(viewModel: overlayViewModel)
        overlayPanel = OverlayPanel(contentView: contentView)

        // Apply stealth settings
        overlayPanel?.sharingType = .none
    }

    private func setupHotkeys() {
        hotkeyManager = HotkeyManager()

        // Cmd+Shift+Space — Toggle overlay visibility
        hotkeyManager.register(
            keyCode: 49, // Space
            modifiers: [.command, .shift]
        ) { [weak self] in
            self?.toggleOverlay()
        }

        // Cmd+Shift+C — Capture + Analyze
        hotkeyManager.register(
            keyCode: 8, // C
            modifiers: [.command, .shift]
        ) { [weak self] in
            self?.captureAndAnalyze()
        }

        // Cmd+Shift+A — Toggle audio capture
        hotkeyManager.register(
            keyCode: 0, // A
            modifiers: [.command, .shift]
        ) { [weak self] in
            self?.toggleAudioCapture()
        }

        // Escape — Hide overlay
        hotkeyManager.register(
            keyCode: 53, // Escape
            modifiers: []
        ) { [weak self] in
            self?.hideOverlay()
        }
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "brain.head.profile", accessibilityDescription: "AI Overlay")
            button.image?.size = NSSize(width: 18, height: 18)
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Overlay (⌘⇧Space)", action: #selector(showOverlay), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Capture Region (⌘⇧C)", action: #selector(captureAndAnalyzeAction), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    // MARK: - Actions

    private func toggleOverlay() {
        guard let panel = overlayPanel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
            overlayViewModel.isVisible = false
        } else {
            stealthManager.applyStealthToWindow(panel)
            panel.makeKeyAndOrderFront(nil)
            overlayViewModel.isVisible = true
        }
    }

    private func hideOverlay() {
        overlayPanel?.orderOut(nil)
        overlayViewModel.isVisible = false
    }

    @objc private func showOverlay() {
        guard let panel = overlayPanel else { return }
        stealthManager.applyStealthToWindow(panel)
        panel.makeKeyAndOrderFront(nil)
        overlayViewModel.isVisible = true
    }

    @objc private func captureAndAnalyzeAction() {
        captureAndAnalyze()
    }

    private func captureAndAnalyze() {
        overlayViewModel.captureAndAnalyze()
    }

    private func toggleAudioCapture() {
        overlayViewModel.toggleAudioCapture()
    }

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Permissions

    private func requestPermissionsIfNeeded() {
        // Screen Recording permission — requested lazily when first capture happens
        // Microphone — requested lazily when audio capture starts
        // Accessibility — needed for global hotkeys, checked on launch

        // Check accessibility
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)
        if !accessibilityEnabled {
            print("⚠️ Accessibility permission required for global hotkeys")
        }
    }
}
