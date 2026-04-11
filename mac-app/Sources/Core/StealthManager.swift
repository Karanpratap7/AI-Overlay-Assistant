import Cocoa
import ScreenCaptureKit

/// Manages the stealth (screen-share invisibility) behavior of the overlay window.
/// Uses multiple techniques to ensure the overlay is invisible to screen capture tools.
final class StealthManager: ObservableObject {

    // MARK: - Published State

    @Published var isStealthActive: Bool = false
    @Published var screenShareDetected: Bool = false

    // MARK: - Properties

    private var monitorTimer: Timer?

    /// Known screen-sharing / recording app bundle identifiers
    private let screenShareApps: Set<String> = [
        "us.zoom.xos",
        "com.microsoft.teams",
        "com.microsoft.teams2",
        "com.cisco.webexmeetingsapp",
        "com.google.Chrome",         // Google Meet via Chrome
        "com.apple.QuickTimePlayerX",
        "com.obsproject.obs-studio",
        "com.loom.desktop",
        "com.apple.screencaptureui",
        "com.apple.screenshot",
        "com.getcleanshot.app",
    ]

    // MARK: - Init

    init() {
        startScreenShareMonitoring()
    }

    deinit {
        monitorTimer?.invalidate()
    }

    // MARK: - Primary Stealth: sharingType = .none

    /// Apply stealth to a window. Must be called BEFORE the window becomes visible,
    /// and re-applied after every `orderFront()` / `makeKeyAndOrderFront()` call.
    func applyStealthToWindow(_ window: NSWindow?) {
        guard let window = window else { return }

        // Technique 1: NSWindow.sharingType = .none
        // This is the official Apple API — excludes the window from ALL screen capture APIs:
        // ScreenCaptureKit, CGWindowListCreate, screencapture CLI, Cmd+Shift+3/4/5, etc.
        window.sharingType = .none

        isStealthActive = true
        print("🔒 Stealth applied: sharingType = .none")
    }

    /// Re-apply stealth after window operations that may reset it.
    func reapplyStealth(_ window: NSWindow?) {
        guard let window = window else { return }
        if window.sharingType != .none {
            window.sharingType = .none
            print("🔒 Stealth re-applied (was reset)")
        }
    }

    // MARK: - Screen Share Detection

    /// Monitors for active screen sharing sessions.
    private func startScreenShareMonitoring() {
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkScreenShareState()
        }
    }

    private func checkScreenShareState() {
        let runningApps = NSWorkspace.shared.runningApplications
        let sharingDetected = runningApps.contains { app in
            guard let bundleId = app.bundleIdentifier else { return false }
            return screenShareApps.contains(bundleId) && app.isActive
        }

        DispatchQueue.main.async { [weak self] in
            if self?.screenShareDetected != sharingDetected {
                self?.screenShareDetected = sharingDetected
                if sharingDetected {
                    print("🔍 Screen sharing app detected as active")
                }
            }
        }
    }

    // MARK: - SCContentFilter Exclusion (for our own captures)

    /// Creates a content filter that excludes the overlay window from captures.
    @available(macOS 13.0, *)
    func createExclusionFilter(
        display: SCDisplay,
        overlayWindow: SCWindow
    ) -> SCContentFilter {
        return SCContentFilter(
            display: display,
            excludingWindows: [overlayWindow]
        )
    }

    // MARK: - Status

    var statusEmoji: String {
        if isStealthActive {
            return "🔒"
        } else {
            return "🔓"
        }
    }

    var statusDescription: String {
        if isStealthActive && screenShareDetected {
            return "Stealth Active — Screen Share Detected"
        } else if isStealthActive {
            return "Stealth Active"
        } else {
            return "Stealth Inactive"
        }
    }
}
