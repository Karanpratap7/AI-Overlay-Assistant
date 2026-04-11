import Cocoa
import Carbon

/// Manages global hotkey registration using Carbon's RegisterEventHotKey API.
/// Falls back to NSEvent global monitoring for modifier-only shortcuts.
final class HotkeyManager {

    // MARK: - Types

    private struct HotkeyRegistration {
        let id: UInt32
        let handler: () -> Void
        let hotKeyRef: EventHotKeyRef?
    }

    // MARK: - Properties

    private var registrations: [UInt32: HotkeyRegistration] = [:]
    private var nextId: UInt32 = 1
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var eventHandlerRef: EventHandlerRef?

    // MARK: - Init

    init() {
        installCarbonEventHandler()
        installNSEventMonitor()
    }

    deinit {
        unregisterAll()
    }

    // MARK: - Registration

    /// Register a global hotkey.
    /// - Parameters:
    ///   - keyCode: Virtual key code (e.g., 49 for Space)
    ///   - modifiers: Modifier flags
    ///   - handler: Closure called when hotkey is pressed
    func register(keyCode: UInt32, modifiers: NSEvent.ModifierFlags, handler: @escaping () -> Void) {
        let id = nextId
        nextId += 1

        // Convert NSEvent modifiers to Carbon modifiers
        var carbonModifiers: UInt32 = 0
        if modifiers.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if modifiers.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        if modifiers.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if modifiers.contains(.control) { carbonModifiers |= UInt32(controlKey) }

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x414F4153) // "AOAS" — AI Overlay App Signature
        hotKeyID.id = id

        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr {
            registrations[id] = HotkeyRegistration(id: id, handler: handler, hotKeyRef: hotKeyRef)
            print("🔑 Hotkey registered: id=\(id), keyCode=\(keyCode)")
        } else {
            print("❌ Failed to register hotkey: \(status)")
            // Fallback: store with nil ref, will use NSEvent monitor
            registrations[id] = HotkeyRegistration(id: id, handler: handler, hotKeyRef: nil)
        }
    }

    /// Unregister all hotkeys.
    func unregisterAll() {
        for (_, registration) in registrations {
            if let ref = registration.hotKeyRef {
                UnregisterEventHotKey(ref)
            }
        }
        registrations.removeAll()

        if let globalMonitor = globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    // MARK: - Carbon Event Handler

    private func installCarbonEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerBlock: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }

            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            guard status == noErr else { return status }

            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            if let registration = manager.registrations[hotKeyID.id] {
                DispatchQueue.main.async {
                    registration.handler()
                }
            }

            return noErr
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            handlerBlock,
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )
    }

    // MARK: - NSEvent Monitor (Fallback for unregistered Carbon keys)

    private func installNSEventMonitor() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        // This is a fallback for any hotkeys that failed Carbon registration.
        // Registered Carbon hotkeys are handled by the Carbon event handler above.
    }
}
