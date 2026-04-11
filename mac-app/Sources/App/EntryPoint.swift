import SwiftUI

@main
struct AIOverlayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No default WindowGroup — windows are managed entirely by AppDelegate.
        // Settings window is also created manually for reliable menu-bar-app behavior.
        Settings {
            EmptyView()
        }
    }
}
