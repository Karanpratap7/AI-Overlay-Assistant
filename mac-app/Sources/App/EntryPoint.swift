import SwiftUI

@main
struct AIOverlayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Main application window — always visible, acts as dashboard
        WindowGroup("AI Overlay Assistant") {
            AppContainerView()
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 600, height: 580)
    }
}

struct AppContainerView: View {
    @EnvironmentObject var appDelegate: AppDelegate
    
    var body: some View {
        if let viewModel = appDelegate.overlayViewModel {
            MainWindowView(viewModel: viewModel)
        } else {
            VStack {
                ProgressView("Loading…")
                    .controlSize(.large)
                Text("Initializing AI Overlay Assistant...")
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
            .frame(width: 400, height: 300)
        }
    }
}
