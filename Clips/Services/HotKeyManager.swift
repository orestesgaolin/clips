import Carbon

/// Registers one or more system-wide hotkeys and dispatches presses to the
/// matching handler by hotkey id.
final class HotKeyManager {
    private struct HotKey {
        let keyCode: () -> UInt32?
        let modifiers: () -> UInt32
        let handler: () -> Void
        var ref: EventHotKeyRef?
    }

    private static let signature = OSType(0x434C4950) // "CLIP"

    private var eventHandler: EventHandlerRef?
    private var hotKeys: [UInt32: HotKey] = [:]

    /// Registers a hotkey definition under `id`. The key code and modifiers are
    /// read lazily on each (re)register so preference changes are picked up.
    /// A `nil` key code means the hotkey is disabled.
    func addHotKey(
        id: UInt32,
        keyCode: @escaping () -> UInt32?,
        modifiers: @escaping () -> UInt32,
        handler: @escaping () -> Void
    ) {
        hotKeys[id] = HotKey(keyCode: keyCode, modifiers: modifiers, handler: handler, ref: nil)
    }

    func register() {
        installEventHandlerIfNeeded()
        for id in hotKeys.keys {
            registerHotKey(id: id)
        }
    }

    func reregister() {
        unregisterHotKeys()
        for id in hotKeys.keys {
            registerHotKey(id: id)
        }
    }

    func unregister() {
        unregisterHotKeys()
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    // MARK: - Private

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, inEvent, userData -> OSStatus in
                guard let userData, let inEvent else { return OSStatus(eventNotHandledErr) }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    inEvent,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return OSStatus(eventNotHandledErr) }

                let mgr = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                let id = hotKeyID.id
                DispatchQueue.main.async {
                    mgr.hotKeys[id]?.handler()
                }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )
    }

    private func registerHotKey(id: UInt32) {
        guard var hotKey = hotKeys[id] else { return }
        guard let keyCode = hotKey.keyCode() else { return }

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        var ref: EventHotKeyRef?
        RegisterEventHotKey(
            keyCode,
            hotKey.modifiers(),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        hotKey.ref = ref
        hotKeys[id] = hotKey
    }

    private func unregisterHotKeys() {
        for (id, var hotKey) in hotKeys {
            if let ref = hotKey.ref {
                UnregisterEventHotKey(ref)
                hotKey.ref = nil
                hotKeys[id] = hotKey
            }
        }
    }

    deinit {
        unregister()
    }
}
