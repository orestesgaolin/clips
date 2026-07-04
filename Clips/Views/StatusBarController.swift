import AppKit
import CoreData
import SwiftUI

final class StatusBarController: NSObject, NSMenuDelegate {
    private let persistence: PersistenceController
    private let monitor: ClipboardMonitor
    private var statusItem: NSStatusItem?
    private var observer: NSObjectProtocol?
    private var menuShortcutObserver: NSObjectProtocol?
    private var activeMenu: NSMenu?
    private var menuKeyMonitor: Any?
    /// When true, selections in the currently open menu paste as plain text.
    /// Set when the menu is opened via the plain-text global hotkey.
    private var plainTextMenuMode = false
    private var preferencesWindowController: PreferencesWindowController?
    private var aboutWindowController: AboutWindowController?

    init(persistence: PersistenceController, monitor: ClipboardMonitor) {
        self.persistence = persistence
        self.monitor = monitor
        super.init()
        setupStatusItem()
        observeChanges()
    }

    private func setupStatusItem() {
        guard Preferences.iconStyle == .shown else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "doc.on.clipboard",
                accessibilityDescription: "Clips"
            )
        }
        item.menu = buildMenu()
        statusItem = item
    }

    private func observeChanges() {
        observer = NotificationCenter.default.addObserver(
            forName: .clipboardDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.statusItem?.menu = self?.buildMenu()
        }

        menuShortcutObserver = NotificationCenter.default.addObserver(
            forName: .menuShortcutPreferencesDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.statusItem?.menu = self?.buildMenu()
        }
    }

    func showMenuAtCursor(plainText: Bool = false) {
        plainTextMenuMode = plainText
        let menu = buildMenu()
        // popUp blocks until the menu is dismissed and the selected item's
        // action has been sent, so it's safe to reset the mode afterwards.
        // (menuDidClose fires *before* the item action, so we can't reset there.)
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        plainTextMenuMode = false
    }

    // MARK: - Menu Construction

    private func buildMenu() -> NSMenu {
        let menu = ClipsMenu()
        menu.delegate = self

        let entries = fetchEntries()
        let inlineCount = min(Preferences.inlineItemCount, entries.count)

        for i in 0..<inlineCount {
            let num = (i + 1) % 10
            let item = menuItem(for: entries[i], prefix: "\(num). ", shortcutNumber: num)
            menu.addItem(item)
        }

        let perFolder = Preferences.itemsPerFolder
        let folderCount = Preferences.folderCount
        var addedFolders = false

        for folderIndex in 0..<folderCount {
            let start = inlineCount + (folderIndex * perFolder)
            let end = min(start + perFolder, entries.count)
            guard start < end else { break }

            if !addedFolders {
                menu.addItem(.separator())
                addedFolders = true
            }

            let rangeStart = start + 1
            let rangeEnd = end
            let shortcutNumber = inlineCount + folderIndex + 1
            let folderItem = NSMenuItem(
                title: "\(shortcutNumber). \(rangeStart) - \(rangeEnd)",
                action: nil,
                keyEquivalent: ""
            )

            let submenu = ClipsMenu()
            submenu.delegate = self
            for (subIndex, i) in (start..<end).enumerated() {
                let num = (subIndex + 1) % 10
                let item = menuItem(for: entries[i], prefix: "\(num). ", shortcutNumber: num)
                submenu.addItem(item)
            }
            menu.addItem(folderItem)
            menu.setSubmenu(submenu, for: folderItem)
        }

        if !entries.isEmpty {
            menu.addItem(.separator())
        }

        let clearItem = NSMenuItem(title: "Clear History", action: #selector(clearHistory), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)
      
        menu.addItem(.separator())
      
        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: "")
        prefsItem.target = self
        menu.addItem(prefsItem)
      
        let aboutItem = NSMenuItem(title: "About Clips", action: #selector(openAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Clips", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        return menu
    }

    private func menuItem(for entry: ClipboardEntry, prefix: String = "", shortcutNumber: Int? = nil) -> NSMenuItem {
        let title = prefix + entry.title
        let item = NSMenuItem(title: title, action: #selector(pasteEntry(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = entry.objectID
        item.tag = shortcutNumber ?? 0

        if let plainText = entry.plainText {
            let maxLen = Preferences.tooltipLength
            item.toolTip = plainText.count > maxLen
                ? String(plainText.prefix(maxLen)) + "..."
                : plainText
        }

        if let hex = ColorDetector.detectHexColor(in: title) {
            item.image = ColorDetector.colorSquare(hex: hex)
        }

        if Preferences.showInlineImages, item.image == nil {
            let imageTypes: Set<String> = ["public.tiff", "public.png", "public.jpeg", "public.heic"]
            if let rep = entry.representationSet.first(where: { imageTypes.contains($0.typeIdentifier) }),
               let image = NSImage(data: rep.data) {
                item.image = scaleImage(image, maxHeight: 36)
            }
        }

        return item
    }

    private func scaleImage(_ image: NSImage, maxHeight: CGFloat) -> NSImage {
        let size = image.size
        guard size.height > 0, size.height > maxHeight else { return image }
        let ratio = maxHeight / size.height
        let newSize = NSSize(width: size.width * ratio, height: maxHeight)
        let scaled = NSImage(size: newSize)
        scaled.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize))
        scaled.unlockFocus()
        return scaled
    }

    // MARK: - Menu Shortcuts

    func menuWillOpen(_ menu: NSMenu) {
        activeMenu = menu
        installMenuKeyMonitorIfNeeded()
    }

    func menuDidClose(_ menu: NSMenu) {
        guard activeMenu === menu else { return }
        activeMenu = nil
        removeMenuKeyMonitor()
        // Note: plainTextMenuMode is intentionally *not* reset here — this
        // fires before the selected item's action. showMenuAtCursor resets it
        // after popUp returns instead.
    }

    private func installMenuKeyMonitorIfNeeded() {
        guard menuKeyMonitor == nil else { return }
        menuKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleMenuShortcut(event) == true ? nil : event
        }
    }

    private func removeMenuKeyMonitor() {
        guard let menuKeyMonitor else { return }
        NSEvent.removeMonitor(menuKeyMonitor)
        self.menuKeyMonitor = nil
    }

    private func handleMenuShortcut(_ event: NSEvent) -> Bool {
        let shortcutModifier = Preferences.menuNumberShortcutModifier
        guard shortcutModifier != .none else { return false }

        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        let base = shortcutModifier.modifierFlags
        let plainModifier = Preferences.plainTextPasteModifier.modifierFlags

        let asPlainText: Bool
        if flags == base {
            // Menu opened via the plain-text hotkey applies to number shortcuts too.
            asPlainText = plainTextMenuMode
        } else if !plainModifier.isEmpty, plainModifier != base, flags == base.union(plainModifier) {
            asPlainText = true
        } else {
            return false
        }

        guard let digit = event.charactersIgnoringModifiers?.first?.wholeNumberValue else { return false }
        guard let item = activeMenu?.items.first(where: { $0.representedObject is NSManagedObjectID && $0.tag == digit }) else { return false }

        activeMenu?.cancelTracking()
        paste(objectID: item.representedObject as? NSManagedObjectID, asPlainText: asPlainText)
        return true
    }

    // MARK: - Actions

    @objc func pasteEntry(_ sender: NSMenuItem) {
        let objectID = sender.representedObject as? NSManagedObjectID
        paste(objectID: objectID, asPlainText: shouldPasteAsPlainText())
    }

    /// Determines whether a menu-item selection should paste plain text: either
    /// the menu is in plain-text mode, or the configured modifier is held.
    private func shouldPasteAsPlainText() -> Bool {
        if plainTextMenuMode { return true }
        let plainModifier = Preferences.plainTextPasteModifier.modifierFlags
        guard !plainModifier.isEmpty else { return false }
        guard let flags = NSApp.currentEvent?.modifierFlags.intersection([.command, .control, .option, .shift]) else { return false }
        return flags.contains(plainModifier)
    }

    private func paste(objectID: NSManagedObjectID?, asPlainText: Bool) {
        guard let objectID else { return }
        guard let entry = try? persistence.context.existingObject(with: objectID) as? ClipboardEntry else { return }

        let pasteboard = NSPasteboard.general
        monitor.shouldSkipNextChange = true
        pasteboard.clearContents()

        if asPlainText, let plainText = entry.plainText {
            pasteboard.setString(plainText, forType: .string)
        } else {
            for rep in entry.representationSet {
                pasteboard.setData(rep.data, forType: NSPasteboard.PasteboardType(rep.typeIdentifier))
            }
        }

        entry.useCount += 1
        if Preferences.pastingMovesToTop {
            entry.createdAt = Date()
        }
        persistence.save()

        DispatchQueue.main.async {
            self.simulatePaste()
        }
    }

    private func simulatePaste() {
        let source = CGEventSource(stateID: .combinedSessionState)
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }

    @objc private func openPreferences() {
        if let controller = preferencesWindowController {
            controller.showWindow(nil)
            return
        }

        let controller = PreferencesWindowController()
        controller.onWindowClose = { [weak self] in
            self?.preferencesWindowController = nil
        }
        preferencesWindowController = controller
        controller.showWindow(nil)
    }

    @objc private func openAbout() {
        if let controller = aboutWindowController {
            controller.showWindow(nil)
            return
        }

        let controller = AboutWindowController()
        controller.onWindowClose = { [weak self] in
            self?.aboutWindowController = nil
        }
        aboutWindowController = controller
        controller.showWindow(nil)
    }

    @objc private func clearHistory() {
        let context = persistence.context
        let request = ClipboardEntry.fetchRequest()
        request.predicate = NSPredicate(format: "isPinned == NO")
        guard let entries = try? context.fetch(request) else { return }
        for entry in entries {
            context.delete(entry)
        }
        persistence.save()
        statusItem?.menu = buildMenu()
    }

    // MARK: - Data

    private func fetchEntries() -> [ClipboardEntry] {
        let request = ClipboardEntry.fetchRequest()
        switch Preferences.sortOrder {
        case .newest:
            request.sortDescriptors = [
                NSSortDescriptor(key: "isPinned", ascending: false),
                NSSortDescriptor(key: "createdAt", ascending: false),
            ]
        case .mostUsed:
            request.sortDescriptors = [
                NSSortDescriptor(key: "isPinned", ascending: false),
                NSSortDescriptor(key: "useCount", ascending: false),
                NSSortDescriptor(key: "createdAt", ascending: false),
            ]
        }
        request.fetchLimit = Preferences.inlineItemCount + Preferences.totalFolderItems
        return (try? persistence.context.fetch(request)) ?? []
    }
}

private final class AboutWindowController: NSWindowController, NSWindowDelegate {
    var onWindowClose: (() -> Void)?

    init() {
        let rootView = AboutView()
        let hostingView = NSHostingView(rootView: rootView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 210),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About Clips"
        window.contentView = hostingView
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
        window?.contentView = nil
        onWindowClose?()
        onWindowClose = nil
    }
}

private struct AboutView: View {
    private let repoURL = URL(string: "https://github.com/orestesgaolin/clips")!

    var body: some View {
        VStack(spacing: 12) {
            Text("Clips")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Version \(AppDelegate.appVersionString)")
                .foregroundStyle(.secondary)

            Link("GitHub Repository", destination: repoURL)
                .font(.body)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
