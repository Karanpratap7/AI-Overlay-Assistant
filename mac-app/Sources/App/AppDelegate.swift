import Cocoa
import SwiftUI
import ScreenCaptureKit

/// Main application delegate — manages lifecycle, permissions, overlay panel, and status bar.
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var overlayPanel: OverlayPanel?
    private(set) var overlayViewModel: OverlayViewModel!
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

        // Setup global hotkeys (from saved settings)
        setupHotkeys()

        // Setup status bar icon
        setupStatusBar()

        // Request permissions lazily
        requestPermissionsIfNeeded()

        // Apply stealth
        stealthManager.applyStealthToWindow(overlayPanel)

        // Listen for hotkey setting changes
        HotkeySettings.shared.onHotkeysChanged = { [weak self] in
            self?.setupHotkeys()
        }

        // Activate the app so the main window appears
        NSApp.activate(ignoringOtherApps: true)

        print("✅ AI Overlay Assistant launched successfully")
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager?.unregisterAll()
        audioCaptureManager?.stopCapture()
    }

    /// Keep the app running when the last window closes (for the menu bar + overlay).
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - Setup

    private func setupOverlayPanel() {
        let contentView = OverlayContentView(viewModel: overlayViewModel)
        overlayPanel = OverlayPanel(contentView: contentView)

        // Apply stealth settings
        overlayPanel?.sharingType = .none
    }

    private func setupHotkeys() {
        // Unregister any existing hotkeys before re-registering
        hotkeyManager?.unregisterAll()
        hotkeyManager = HotkeyManager()

        let settings = HotkeySettings.shared

        // Toggle overlay visibility
        hotkeyManager.register(
            keyCode: settings.toggleOverlay.keyCode,
            modifiers: NSEvent.ModifierFlags(rawValue: settings.toggleOverlay.modifiers)
        ) { [weak self] in
            self?.toggleOverlay()
        }

        // Capture + Analyze
        hotkeyManager.register(
            keyCode: settings.captureRegion.keyCode,
            modifiers: NSEvent.ModifierFlags(rawValue: settings.captureRegion.modifiers)
        ) { [weak self] in
            self?.captureAndAnalyze()
        }

        // Toggle audio capture
        hotkeyManager.register(
            keyCode: settings.toggleAudio.keyCode,
            modifiers: NSEvent.ModifierFlags(rawValue: settings.toggleAudio.modifiers)
        ) { [weak self] in
            self?.toggleAudioCapture()
        }

        // Hide overlay
        hotkeyManager.register(
            keyCode: settings.hideOverlay.keyCode,
            modifiers: NSEvent.ModifierFlags(rawValue: settings.hideOverlay.modifiers)
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
        menu.addItem(NSMenuItem(title: "Show Overlay", action: #selector(showOverlay), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Capture Region", action: #selector(captureAndAnalyzeAction), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Show Main Window", action: #selector(showMainWindow), keyEquivalent: ""))
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

    @objc private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        // The WindowGroup is managed by SwiftUI; activating the app brings it forward.
        // If the user closed the window, open a new one via the standard command.
        if NSApp.windows.filter({ $0 !== overlayPanel && $0.isVisible }).isEmpty {
            NSApp.sendAction(#selector(NSWindow.makeKeyAndOrderFront(_:)), to: nil, from: nil)
        }
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
