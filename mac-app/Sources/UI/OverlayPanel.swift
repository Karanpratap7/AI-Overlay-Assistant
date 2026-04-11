import Cocoa
import SwiftUI

/// Custom NSPanel configured for floating, translucent overlay behavior.
/// The panel is invisible to all screen capture tools via `sharingType = .none`.
class OverlayPanel: NSPanel {

    // MARK: - Init

    init<Content: View>(contentView: Content) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 520),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        configure()
        setupContent(contentView)
        positionOnScreen()
    }

    // MARK: - Configuration

    private func configure() {
        // Floating behavior
        level = .floating
        isFloatingPanel = true

        // Transparency
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        // Collection behavior — appear on all spaces, work with fullscreen
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .transient
        ]

        // 🔒 STEALTH: invisible to ALL screen capture tools
        sharingType = .none

        // Interaction
        ignoresMouseEvents = false
        isMovableByWindowBackground = true
        acceptsMouseMovedEvents = true

        // Don't show in dock or app switcher
        hidesOnDeactivate = false

        // Rounded corners
        isReleasedWhenClosed = false

        // Title bar
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
    }

    private func setupContent<Content: View>(_ view: Content) {
        let hostingView = NSHostingView(rootView: view)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        // Create a plain container so AutoLayout doesn't fight the window frame
        let container = NSView(frame: contentRect(forFrameRect: frame))
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true

        container.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: container.topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        contentView = container
    }

    private func positionOnScreen() {
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let panelFrame = frame

        // Position in bottom-right corner with padding
        let x = screenFrame.maxX - panelFrame.width - 24
        let y = screenFrame.minY + 24

        setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Overrides

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func makeKeyAndOrderFront(_ sender: Any?) {
        super.makeKeyAndOrderFront(sender)
        // Re-apply stealth after ordering front (macOS may reset it)
        sharingType = .none
    }

    override func orderFront(_ sender: Any?) {
        super.orderFront(sender)
        sharingType = .none
    }

    // MARK: - Animation

    func showWithAnimation() {
        alphaValue = 0
        makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().alphaValue = 1.0
        }
    }

    func hideWithAnimation(completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
            self?.alphaValue = 1.0
            completion?()
        })
    }

    // MARK: - Resize

    func updateSize(width: CGFloat, height: CGFloat) {
        let origin = frame.origin
        setFrame(NSRect(x: origin.x, y: origin.y, width: width, height: height), display: true, animate: true)
    }
}
