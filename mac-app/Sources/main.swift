import Cocoa

let delegate = MainActor.assumeIsolated {
    AppDelegate()
}
MainActor.assumeIsolated {
    NSApplication.shared.delegate = delegate
}
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)