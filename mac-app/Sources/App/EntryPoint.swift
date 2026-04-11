import SwiftUI

@main
struct AIOverlayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Main application window — always visible, acts as dashboard
        WindowGroup("AI Overlay Assistant") {
            if let viewModel = appDelegate.overlayViewModel {
                MainWindowView(viewModel: viewModel)
                    .preferredColorScheme(.dark)
            } else {
                ProgressView("Loading…")
                    .frame(width: 400, height: 300)
            }
        }
        .defaultSize(width: 600, height: 580)
    }
}
