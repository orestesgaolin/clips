import AppKit

class ClipsMenu: NSMenu {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function])

        if mods.isEmpty,
           let chars = event.charactersIgnoringModifiers,
           let num = Int(chars), num >= 1, num <= 9 {
            for item in items where item.tag == num {
                if item.hasSubmenu, let submenu = item.submenu {
                    cancelTracking()
                    DispatchQueue.main.async {
                        submenu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
                    }
                    return true
                }
                if let action = item.action, let target = item.target {
                    cancelTracking()
                    DispatchQueue.main.async {
                        NSApp.sendAction(action, to: target, from: item)
                    }
                    return true
                }
            }
        }

        return super.performKeyEquivalent(with: event)
    }
}
