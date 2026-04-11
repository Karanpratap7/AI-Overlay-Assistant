// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AIOverlayAssistant",
    platforms: [
        .macOS(.v13) // Ventura 13.0+ required for ScreenCaptureKit + SCContentFilter
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "AIOverlayAssistant",
            dependencies: [],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
