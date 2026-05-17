import AppKit
import SwiftUI
import Darwin

private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class PreferencesWindowController: NSWindowController, NSWindowDelegate {
    var onWindowClose: (() -> Void)?

    init() {
        let hostingView = FirstMouseHostingView(rootView: PreferencesView())
        let fittingSize = hostingView.fittingSize

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: fittingSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Clips Preferences"
        window.contentView = hostingView
        window.setContentSize(fittingSize)
        window.center()
        window.isReleasedWhenClosed = true
        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(sender)
        window?.makeFirstResponder(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // Release the SwiftUI view graph as soon as the preferences window closes.
        window?.contentView = nil
        releaseTransientMemory()
        onWindowClose?()
        onWindowClose = nil
    }

    private func releaseTransientMemory() {
        let context = PersistenceController.shared.context
        context.perform {
            // Refault registered objects loaded while browsing preferences/history.
            context.refreshAllObjects()
        }

        // Hint malloc to reclaim purgeable caches after UI teardown.
        _ = malloc_zone_pressure_relief(nil, 0)
    }
}
