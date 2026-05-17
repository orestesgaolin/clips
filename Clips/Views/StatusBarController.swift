import AppKit
import CoreData

final class StatusBarController: NSObject, NSMenuDelegate {
    private let persistence: PersistenceController
    private let monitor: ClipboardMonitor
    private var statusItem: NSStatusItem?
    private var observer: NSObjectProtocol?
    private var preferencesWindowController: PreferencesWindowController?

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
    }

    func showMenuAtCursor() {
        let menu = buildMenu()
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    // MARK: - Menu Construction

    private func buildMenu() -> NSMenu {
        let menu = ClipsMenu()

        let entries = fetchEntries()
        let inlineCount = min(Preferences.inlineItemCount, entries.count)

        for i in 0..<inlineCount {
            let item = menuItem(for: entries[i])
            let keyNum = i + 1
            if keyNum <= 9 {
                item.keyEquivalent = "\(keyNum)"
                item.keyEquivalentModifierMask = []
                item.tag = keyNum
            }
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

            let folderNumber = inlineCount + folderIndex + 1
            let folderItem = NSMenuItem(title: "Folder \(folderIndex + 1)", action: nil, keyEquivalent: "")
            if folderNumber <= 9 {
                folderItem.keyEquivalent = "\(folderNumber)"
                folderItem.keyEquivalentModifierMask = []
                folderItem.tag = folderNumber
            }

            let submenu = ClipsMenu()
            for (subIndex, i) in (start..<end).enumerated() {
                let item = menuItem(for: entries[i])
                let keyNum = subIndex + 1
                if keyNum <= 9 {
                    item.keyEquivalent = "\(keyNum)"
                    item.keyEquivalentModifierMask = []
                    item.tag = keyNum
                }
                submenu.addItem(item)
            }
            menu.addItem(folderItem)
            menu.setSubmenu(submenu, for: folderItem)
        }

        if !entries.isEmpty {
            menu.addItem(.separator())
        }

        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: "")
        prefsItem.target = self
        menu.addItem(prefsItem)

        let clearItem = NSMenuItem(title: "Clear History", action: #selector(clearHistory), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Clips", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        return menu
    }

    private func menuItem(for entry: ClipboardEntry) -> NSMenuItem {
        let title = entry.title
        let item = NSMenuItem(title: title, action: #selector(pasteEntry(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = entry.objectID

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

    // MARK: - Actions

    @objc func pasteEntry(_ sender: NSMenuItem) {
        guard let objectID = sender.representedObject as? NSManagedObjectID else { return }
        guard let entry = try? persistence.context.existingObject(with: objectID) as? ClipboardEntry else { return }

        let pasteboard = NSPasteboard.general
        monitor.shouldSkipNextChange = true
        pasteboard.clearContents()

        for rep in entry.representationSet {
            pasteboard.setData(rep.data, forType: NSPasteboard.PasteboardType(rep.typeIdentifier))
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
