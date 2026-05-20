import AppKit
import CoreData
import CryptoKit

final class ClipboardMonitor {
    private let persistence: PersistenceController
    private var timer: Timer?
    private var lastChangeCount: Int
    var shouldSkipNextChange = false

    init(persistence: PersistenceController) {
        self.persistence = persistence
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func checkForChanges() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        if shouldSkipNextChange {
            shouldSkipNextChange = false
            return
        }

        guard let items = pasteboard.pasteboardItems, let item = items.first else { return }
        let types = item.types
        guard !types.isEmpty else { return }

        if let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           Preferences.ignoredApps.contains(bundleId) {
            return
        }

        var representations: [(String, Data)] = []
        for type in types {
            if let data = item.data(forType: type) {
                representations.append((type.rawValue, data))
            }
        }
        guard !representations.isEmpty else { return }

        let hash = computeHash(representations)
        let context = persistence.context

        // Check for existing entry with this hash
        let request = ClipboardEntry.fetchRequest()
        request.predicate = NSPredicate(format: "contentHash == %@", hash)
        request.fetchLimit = 1

        do {
            if let existing = try context.fetch(request).first {
                if Preferences.pastingMovesToTop {
                    existing.createdAt = Date()
                    persistence.save()
                    NotificationCenter.default.post(name: .clipboardDidChange, object: nil)
                }
                return
            }
        } catch {
            print("Clipboard fetch error: \(error)")
        }

        let entry = ClipboardEntry(context: context)
        entry.id = UUID()
        entry.createdAt = Date()
        entry.useCount = 0
        entry.isPinned = false
        entry.contentHash = hash
        entry.sourceAppBundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        entry.sourceAppName = NSWorkspace.shared.frontmostApplication?.localizedName
        entry.title = generateTitle(item: item, types: types)

        for (typeId, data) in representations {
            let rep = ClipboardRepresentation(context: context)
            rep.typeIdentifier = typeId
            rep.data = data
            rep.entry = entry
        }

        persistence.save()
        enforceMaxHistory()
        NotificationCenter.default.post(name: .clipboardDidChange, object: nil)
    }

    private func computeHash(_ representations: [(String, Data)]) -> String {
        var hasher = SHA256()
        for (type, data) in representations.sorted(by: { $0.0 < $1.0 }) {
            hasher.update(data: Data(type.utf8))
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private func generateTitle(item: NSPasteboardItem, types: [NSPasteboard.PasteboardType]) -> String {
        if let text = item.string(forType: .string) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .newlines)
                .joined(separator: " ")
            if trimmed.isEmpty { return "[Empty]" }
            let maxChars = Preferences.menuCharacterCount
            return trimmed.count > maxChars ? String(trimmed.prefix(maxChars)) + "..." : trimmed
        }

        let imageTypes: Set<String> = ["public.tiff", "public.png", "public.jpeg", "public.heic"]
        if types.contains(where: { imageTypes.contains($0.rawValue) }) {
            return "[Image]"
        }
        if types.contains(where: { $0.rawValue == "com.adobe.pdf" }) {
            return "[PDF]"
        }
        if types.contains(.fileURL) {
            if let urlStr = item.string(forType: .fileURL),
               let url = URL(string: urlStr) {
                return url.lastPathComponent
            }
            return "[File]"
        }
        if types.contains(.URL) {
            return item.string(forType: .URL) ?? "[URL]"
        }
        if types.contains(.rtf) { return "[Rich Text]" }
        if types.contains(.html) { return "[HTML]" }
        return "[Clipboard Data]"
    }

    private func enforceMaxHistory() {
        let context = persistence.context
        let request = ClipboardEntry.fetchRequest()
        request.predicate = NSPredicate(format: "isPinned == NO")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        guard let entries = try? context.fetch(request) else { return }
        let max = Preferences.maxHistory
        guard entries.count > max else { return }
        for entry in entries[max...] {
            context.delete(entry)
        }
        persistence.save()
    }
}

extension Notification.Name {
    static let clipboardDidChange = Notification.Name("ClipboardDidChange")
}
