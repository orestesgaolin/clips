import SwiftUI
import ServiceManagement
import UniformTypeIdentifiers

struct PreferencesView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gear") }
            AppearanceTab()
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            HistoryTab()
                .tabItem { Label("History", systemImage: "clock") }
            IgnoredAppsTab()
                .tabItem { Label("Ignored Apps", systemImage: "xmark.app") }
        }
        .frame(width: 520, height: 420)
    }
}

// MARK: - General

private struct GeneralTab: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("maxHistory") private var maxHistory = 100
    @AppStorage("sortOrder") private var sortOrder = "newest"
    @AppStorage("pastingMovesToTop") private var pastingMovesToTop = true

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    toggleLoginItem(enabled: newValue)
                }

            HStack {
                Text("Max history:")
                TextField("", value: $maxHistory, format: .number)
                    .frame(width: 80)
                Stepper("", value: $maxHistory, in: 10...10000, step: 10)
                    .labelsHidden()
            }

            Picker("Sort order:", selection: $sortOrder) {
                Text("Newest First").tag("newest")
                Text("Most Used").tag("mostUsed")
            }
            .pickerStyle(.menu)

            Toggle("Pasting moves item to top", isOn: $pastingMovesToTop)

            HStack {
                Text("Paste shortcut:")
                ShortcutRecorderView()
            }
        }
        .padding()
    }

    private func toggleLoginItem(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Login item toggle failed: \(error)")
        }
    }
}

// MARK: - Appearance

private struct AppearanceTab: View {
    @AppStorage("iconStyle") private var iconStyle = "shown"
    @AppStorage("inlineItemCount") private var inlineItemCount = 10
    @AppStorage("folderCount") private var folderCount = 4
    @AppStorage("itemsPerFolder") private var itemsPerFolder = 9
    @AppStorage("menuCharacterCount") private var menuCharacterCount = 50
    @AppStorage("tooltipLength") private var tooltipLength = 200
    @AppStorage("showInlineImages") private var showInlineImages = true

    var body: some View {
        Form {
            Picker("Status icon:", selection: $iconStyle) {
                Text("Shown").tag("shown")
                Text("Hidden").tag("hidden")
            }
            .pickerStyle(.menu)

            HStack {
                Text("Items inline:")
                TextField("", value: $inlineItemCount, format: .number)
                    .frame(width: 60)
                Stepper("", value: $inlineItemCount, in: 1...30)
                    .labelsHidden()
            }

            HStack {
                Text("Number of folders:")
                TextField("", value: $folderCount, format: .number)
                    .frame(width: 60)
                Stepper("", value: $folderCount, in: 0...10)
                    .labelsHidden()
            }

            HStack {
                Text("Items per folder:")
                TextField("", value: $itemsPerFolder, format: .number)
                    .frame(width: 60)
                Stepper("", value: $itemsPerFolder, in: 1...30)
                    .labelsHidden()
            }

            HStack {
                Text("Characters in menu:")
                TextField("", value: $menuCharacterCount, format: .number)
                    .frame(width: 60)
                Stepper("", value: $menuCharacterCount, in: 10...500)
                    .labelsHidden()
            }

            HStack {
                Text("Tooltip length:")
                TextField("", value: $tooltipLength, format: .number)
                    .frame(width: 60)
                Stepper("", value: $tooltipLength, in: 0...2000, step: 50)
                    .labelsHidden()
            }

            Toggle("Show inline images", isOn: $showInlineImages)
        }
        .padding()
    }
}

// MARK: - History

private struct HistoryTab: View {
    @State private var entries: [ClipboardEntry] = []
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search history...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(6)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)

            List {
                ForEach(filteredEntries, id: \.objectID) { entry in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title)
                                .lineLimit(1)
                            HStack(spacing: 8) {
                                if let app = entry.sourceAppName {
                                    Text(app)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(entry.createdAt, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                if entry.useCount > 0 {
                                    Text("used \(entry.useCount)x")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        Spacer()
                        Button {
                            copyToClipboard(entry)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .help("Copy to clipboard")

                        Button {
                            deleteEntry(entry)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                        .help("Delete")
                    }
                }
            }

            HStack {
                Text("\(entries.count) entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding()
        .onAppear { loadEntries() }
    }

    private var filteredEntries: [ClipboardEntry] {
        guard !searchText.isEmpty else { return entries }
        return entries.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    private func loadEntries() {
        let request = ClipboardEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        request.relationshipKeyPathsForPrefetching = []
        request.propertiesToFetch = ["title", "createdAt", "useCount", "sourceAppName", "isPinned"]
        request.returnsObjectsAsFaults = false
        entries = (try? PersistenceController.shared.context.fetch(request)) ?? []
    }

    private func copyToClipboard(_ entry: ClipboardEntry) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        for rep in entry.representationSet {
            pasteboard.setData(rep.data, forType: NSPasteboard.PasteboardType(rep.typeIdentifier))
        }
    }

    private func deleteEntry(_ entry: ClipboardEntry) {
        let context = PersistenceController.shared.context
        context.delete(entry)
        PersistenceController.shared.save()
        loadEntries()
    }
}

// MARK: - Ignored Apps

private struct IgnoredAppsTab: View {
    @State private var ignoredApps: [String] = Preferences.ignoredApps

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Clipboard changes from these apps will be ignored:")
                .font(.callout)
                .foregroundStyle(.secondary)

            List {
                ForEach(ignoredApps, id: \.self) { bundleId in
                    HStack {
                        if let icon = appIcon(for: bundleId) {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 20, height: 20)
                        }
                        Text(appName(for: bundleId) ?? bundleId)
                        Spacer()
                        if appName(for: bundleId) != nil {
                            Text(bundleId)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Button {
                            if let idx = ignoredApps.firstIndex(of: bundleId) {
                                ignoredApps.remove(at: idx)
                                Preferences.ignoredApps = ignoredApps
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .frame(minHeight: 120)

            HStack {
                Button("Add App...") {
                    pickApplication()
                }
                Spacer()
            }
        }
        .padding()
    }

    private func pickApplication() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK,
                  let url = panel.url,
                  let bundle = Bundle(url: url),
                  let bundleId = bundle.bundleIdentifier,
                  !ignoredApps.contains(bundleId)
            else { return }
            ignoredApps.append(bundleId)
            Preferences.ignoredApps = ignoredApps
        }
    }

    private func appName(for bundleId: String) -> String? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else { return nil }
        return Bundle(url: url)?.infoDictionary?["CFBundleName"] as? String
            ?? FileManager.default.displayName(atPath: url.path)
    }

    private func appIcon(for bundleId: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
