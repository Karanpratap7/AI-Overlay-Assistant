import SwiftUI

@main
struct AIOverlayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // We use a Settings scene so we don't get a default window.
        // The overlay panel is managed by AppDelegate.
        Settings {
            SettingsView()
        }
    }
}
