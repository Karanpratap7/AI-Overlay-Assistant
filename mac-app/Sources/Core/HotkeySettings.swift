import Cocoa

/// Persistent hotkey settings stored in UserDefaults.
/// Each hotkey has a key code and modifier flags that the user can customize.
final class HotkeySettings: ObservableObject {

    static let shared = HotkeySettings()

    // MARK: - Types

    struct Shortcut: Codable, Equatable {
        var keyCode: UInt32
        var modifiers: UInt         // Raw NSEvent.ModifierFlags value

        var displayString: String {
            var parts: [String] = []
            let flags = NSEvent.ModifierFlags(rawValue: modifiers)
            if flags.contains(.control) { parts.append("⌃") }
            if flags.contains(.option) { parts.append("⌥") }
            if flags.contains(.shift) { parts.append("⇧") }
            if flags.contains(.command) { parts.append("⌘") }
            parts.append(Self.keyName(for: keyCode))
            return parts.joined()
        }

        static func keyName(for keyCode: UInt32) -> String {
            let names: [UInt32: String] = [
                0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
                8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
                16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
                23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
                30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return",
                37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
                44: "/", 45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space",
                50: "`", 51: "Delete", 53: "Escape", 76: "Enter",
                96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
                101: "F9", 109: "F10", 111: "F12", 103: "F11",
                105: "F13", 107: "F14", 113: "F15",
                118: "F4", 120: "F2", 122: "F1",
                123: "←", 124: "→", 125: "↓", 126: "↑"
            ]
            return names[keyCode] ?? "Key\(keyCode)"
        }
    }

    // MARK: - Keys

    private let toggleOverlayKey = "hotkey_toggleOverlay"
    private let captureRegionKey = "hotkey_captureRegion"
    private let toggleAudioKey = "hotkey_toggleAudio"
    private let hideOverlayKey = "hotkey_hideOverlay"

    // MARK: - Defaults

    static let defaultToggleOverlay = Shortcut(keyCode: 49, modifiers: NSEvent.ModifierFlags([.command, .shift]).rawValue)
    static let defaultCaptureRegion = Shortcut(keyCode: 8, modifiers: NSEvent.ModifierFlags([.command, .shift]).rawValue)
    static let defaultToggleAudio = Shortcut(keyCode: 0, modifiers: NSEvent.ModifierFlags([.command, .shift]).rawValue)
    static let defaultHideOverlay = Shortcut(keyCode: 53, modifiers: 0)

    // MARK: - Published

    @Published var toggleOverlay: Shortcut
    @Published var captureRegion: Shortcut
    @Published var toggleAudio: Shortcut
    @Published var hideOverlay: Shortcut

    /// Called when hotkeys change and need re-registration.
    var onHotkeysChanged: (() -> Void)?

    // MARK: - Init

    private init() {
        toggleOverlay = Self.load(key: "hotkey_toggleOverlay") ?? Self.defaultToggleOverlay
        captureRegion = Self.load(key: "hotkey_captureRegion") ?? Self.defaultCaptureRegion
        toggleAudio = Self.load(key: "hotkey_toggleAudio") ?? Self.defaultToggleAudio
        hideOverlay = Self.load(key: "hotkey_hideOverlay") ?? Self.defaultHideOverlay
    }

    // MARK: - Persistence

    func save() {
        Self.store(key: toggleOverlayKey, shortcut: toggleOverlay)
        Self.store(key: captureRegionKey, shortcut: captureRegion)
        Self.store(key: toggleAudioKey, shortcut: toggleAudio)
        Self.store(key: hideOverlayKey, shortcut: hideOverlay)
        onHotkeysChanged?()
    }

    func resetToDefaults() {
        toggleOverlay = Self.defaultToggleOverlay
        captureRegion = Self.defaultCaptureRegion
        toggleAudio = Self.defaultToggleAudio
        hideOverlay = Self.defaultHideOverlay
        save()
    }

    private static func store(key: String, shortcut: Shortcut) {
        if let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private static func load(key: String) -> Shortcut? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Shortcut.self, from: data)
    }
}
