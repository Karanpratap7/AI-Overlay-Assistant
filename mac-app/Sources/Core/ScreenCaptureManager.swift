import Foundation
import ScreenCaptureKit
import CoreGraphics
import AppKit

/// Manages screen capture using ScreenCaptureKit (macOS 12.3+).
/// Captures selected regions and excludes the overlay window from captures.
@available(macOS 13.0, *)
final class ScreenCaptureManager: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var isCapturing = false
    @Published var lastCapturedImage: CGImage?
    @Published var selectedRegion: CGRect?
    @Published var hasPermission = false

    // MARK: - Properties

    private var stream: SCStream?
    private var streamOutput: CaptureStreamOutput?

    // MARK: - Permission Check

    func checkPermission() async {
        do {
            // This will trigger the permission prompt if not already granted
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            await MainActor.run {
                self.hasPermission = !content.displays.isEmpty
            }
        } catch {
            print("❌ Screen capture permission denied: \(error.localizedDescription)")
            await MainActor.run {
                self.hasPermission = false
            }
        }
    }

    // MARK: - Capture Region

    /// Captures a screenshot of the specified region (or full screen if nil).
    func captureRegion(_ region: CGRect? = nil) async -> CGImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

            guard let display = content.displays.first else {
                print("❌ No display found")
                return nil
            }

            // Exclude our overlay window from the capture
            let overlayWindows = content.windows.filter { window in
                window.owningApplication?.bundleIdentifier == Bundle.main.bundleIdentifier
            }

            let filter = SCContentFilter(
                display: display,
                excludingWindows: overlayWindows
            )

            let config = SCStreamConfiguration()

            if let region = region ?? selectedRegion {
                // Capture specific region
                config.sourceRect = region
                config.width = Int(region.width) * 2 // Retina
                config.height = Int(region.height) * 2
            } else {
                // Full screen
                config.width = Int(display.width) * 2
                config.height = Int(display.height) * 2
            }

            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.showsCursor = false

            // Capture single frame
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )

            await MainActor.run {
                self.lastCapturedImage = image
            }

            print("📸 Screen captured: \(image.width)x\(image.height)")
            return image

        } catch {
            print("❌ Screen capture failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Region Selection

    /// Sets the capture region.
    func setRegion(_ rect: CGRect) {
        selectedRegion = rect
        print("📐 Capture region set: \(rect)")
    }

    /// Clears the capture region (will capture full screen).
    func clearRegion() {
        selectedRegion = nil
        print("📐 Capture region cleared — will capture full screen")
    }

    // MARK: - Image Conversion

    /// Converts a CGImage to JPEG Data for API transmission.
    func imageToJPEGData(_ image: CGImage, quality: CGFloat = 0.85) -> Data? {
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: quality])
    }

    /// Converts a CGImage to PNG Data.
    func imageToPNGData(_ image: CGImage) -> Data? {
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        return bitmapRep.representation(using: .png, properties: [:])
    }

    /// Converts a CGImage to base64 string for API requests.
    func imageToBase64(_ image: CGImage, format: NSBitmapImageRep.FileType = .jpeg) -> String? {
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        let data: Data?
        switch format {
        case .jpeg:
            data = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
        case .png:
            data = bitmapRep.representation(using: .png, properties: [:])
        default:
            data = bitmapRep.representation(using: .jpeg, properties: [:])
        }
        return data?.base64EncodedString()
    }
}

// MARK: - Stream Output Handler

@available(macOS 13.0, *)
private class CaptureStreamOutput: NSObject, SCStreamOutput {
    var capturedImage: CGImage?
    var onCapture: ((CGImage) -> Void)?

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        guard let imageBuffer = sampleBuffer.imageBuffer else { return }

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }

        capturedImage = cgImage
        onCapture?(cgImage)
    }
}
