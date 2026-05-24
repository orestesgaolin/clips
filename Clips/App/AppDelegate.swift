import AppKit
#if !APP_STORE
import Sparkle
#endif

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var appVersionString: String {
        let shortVersion = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "Unknown"
        let buildNumber = (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "Unknown"
        return "\(shortVersion) (\(buildNumber))"
    }

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
#if !APP_STORE
    private var updaterController: SPUStandardUpdaterController?
#endif

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

#if !APP_STORE
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        updaterController?.updater.checkForUpdatesInBackground()
#endif
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyManager.unregister()
        clipboardMonitor.stop()
    }

    @objc func checkForUpdates(_ sender: Any?) {
#if !APP_STORE
        updaterController?.checkForUpdates(sender)
#endif
    }

    private func requestAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}

extension Notification.Name {
    static let hotKeyDidChange = Notification.Name("HotKeyDidChange")
}
