import SwiftUI
import AppKit

/// Full-screen transparent overlay for click-and-drag region selection.
/// Behaves like the macOS screenshot tool (Cmd+Shift+4).
struct RegionSelectorView: View {
    @Binding var selectedRegion: CGRect?
    @Binding var isSelecting: Bool

    @State private var startPoint: CGPoint?
    @State private var currentPoint: CGPoint?
    @State private var dragRect: CGRect = .zero

    var onRegionSelected: ((CGRect) -> Void)?

    var body: some View {
        ZStack {
            // Semi-transparent overlay covering entire screen
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            // Selection rectangle
            if let start = startPoint, let current = currentPoint {
                let rect = selectionRect(from: start, to: current)

                // Clear cutout for selected region
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .overlay(
                        Rectangle()
                            .stroke(Color.cyan, lineWidth: 2)
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                    )

                // Dimension label
                VStack {
                    Text("\(Int(rect.width)) × \(Int(rect.height))")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(6)
                }
                .position(x: rect.midX, y: rect.maxY + 20)
            }

            // Instructions
            if startPoint == nil {
                VStack(spacing: 8) {
                    Text("Click and drag to select a region")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white)

                    Text("Press Escape to cancel")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(20)
                .background(Color.black.opacity(0.6))
                .cornerRadius(12)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    if startPoint == nil {
                        startPoint = value.startLocation
                    }
                    currentPoint = value.location
                }
                .onEnded { value in
                    if let start = startPoint {
                        let rect = selectionRect(from: start, to: value.location)
                        if rect.width > 10 && rect.height > 10 {
                            selectedRegion = rect
                            onRegionSelected?(rect)
                        }
                    }

                    // Reset state
                    startPoint = nil
                    currentPoint = nil
                    isSelecting = false
                }
        )
        .onExitCommand {
            // Escape key
            startPoint = nil
            currentPoint = nil
            isSelecting = false
        }
    }

    private func selectionRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        let x = min(start.x, end.x)
        let y = min(start.y, end.y)
        let width = abs(end.x - start.x)
        let height = abs(end.y - start.y)
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

// MARK: - Region Selector Window

/// Manages a full-screen transparent window for region selection.
class RegionSelectorWindowController {
    private var window: NSWindow?
    private var onComplete: ((CGRect?) -> Void)?

    func showSelector(completion: @escaping (CGRect?) -> Void) {
        self.onComplete = completion

        guard let screen = NSScreen.main else {
            completion(nil)
            return
        }

        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = false
        window.sharingType = .none // Keep selector invisible too
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        var selectedRegion: CGRect? = nil
        var isSelecting = true

        let selectorView = RegionSelectorView(
            selectedRegion: Binding(
                get: { selectedRegion },
                set: { selectedRegion = $0 }
            ),
            isSelecting: Binding(
                get: { isSelecting },
                set: { newValue in
                    isSelecting = newValue
                    if !newValue {
                        window.orderOut(nil)
                        completion(selectedRegion)
                    }
                }
            )
        )

        window.contentView = NSHostingView(rootView: selectorView)
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }
}
