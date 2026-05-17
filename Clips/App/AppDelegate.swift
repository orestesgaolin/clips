import AppKit
import Sparkle

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    private var statusBarController: StatusBarController!
    private var clipboardMonitor: ClipboardMonitor!
    private var hotKeyManager: HotKeyManager!
    private var hotKeyObserver: NSObjectProtocol?
    private var updaterController: SPUStandardUpdaterController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestAccessibilityIfNeeded()

        let persistence = PersistenceController.shared
        clipboardMonitor = ClipboardMonitor(persistence: persistence)
        statusBarController = StatusBarController(persistence: persistence, monitor: clipboardMonitor)
        hotKeyManager = HotKeyManager { [weak self] in
            self?.statusBarController.showMenuAtCursor()
        }
        clipboardMonitor.start()
        hotKeyManager.register()

        hotKeyObserver = NotificationCenter.default.addObserver(
            forName: .hotKeyDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.hotKeyManager.reregister()
        }

        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        updaterController?.updater.checkForUpdatesInBackground()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyManager.unregister()
        clipboardMonitor.stop()
    }

    @objc func checkForUpdates(_ sender: Any?) {
        updaterController?.checkForUpdates(sender)
    }

    private func requestAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}

extension Notification.Name {
    static let hotKeyDidChange = Notification.Name("HotKeyDidChange")
}
