import Foundation
import Carbon.HIToolbox

enum Preferences {
    private static let defaults = UserDefaults.standard

    static var hotKeyCode: UInt32 {
        get {
            defaults.object(forKey: "hotKeyCode") != nil
                ? UInt32(defaults.integer(forKey: "hotKeyCode"))
                : UInt32(kVK_ANSI_V)
        }
        set { defaults.set(Int(newValue), forKey: "hotKeyCode") }
    }

    static var hotKeyModifiers: UInt32 {
        get {
            defaults.object(forKey: "hotKeyModifiers") != nil
                ? UInt32(defaults.integer(forKey: "hotKeyModifiers"))
                : UInt32(cmdKey | shiftKey)
        }
        set { defaults.set(Int(newValue), forKey: "hotKeyModifiers") }
    }

    enum SortOrder: String, CaseIterable {
        case newest
        case mostUsed

        var displayName: String {
            switch self {
            case .newest: return "Newest First"
            case .mostUsed: return "Most Used"
            }
        }
    }

    enum IconStyle: String, CaseIterable {
        case shown
        case hidden

        var displayName: String {
            switch self {
            case .shown: return "Shown"
            case .hidden: return "Hidden"
            }
        }
    }

    static var launchAtLogin: Bool {
        get { defaults.bool(forKey: "launchAtLogin") }
        set { defaults.set(newValue, forKey: "launchAtLogin") }
    }

    static var maxHistory: Int {
        get {
            let val = defaults.integer(forKey: "maxHistory")
            return val > 0 ? val : 100
        }
        set { defaults.set(newValue, forKey: "maxHistory") }
    }

    static var sortOrder: SortOrder {
        get { SortOrder(rawValue: defaults.string(forKey: "sortOrder") ?? "") ?? .newest }
        set { defaults.set(newValue.rawValue, forKey: "sortOrder") }
    }

    static var iconStyle: IconStyle {
        get { IconStyle(rawValue: defaults.string(forKey: "iconStyle") ?? "") ?? .shown }
        set { defaults.set(newValue.rawValue, forKey: "iconStyle") }
    }

    static var inlineItemCount: Int {
        get {
            let val = defaults.integer(forKey: "inlineItemCount")
            return val > 0 ? val : 10
        }
        set { defaults.set(newValue, forKey: "inlineItemCount") }
    }

    static var folderCount: Int {
        get {
            let val = defaults.integer(forKey: "folderCount")
            return val > 0 ? val : 4
        }
        set { defaults.set(newValue, forKey: "folderCount") }
    }

    static var itemsPerFolder: Int {
        get {
            let val = defaults.integer(forKey: "itemsPerFolder")
            return val > 0 ? val : 9
        }
        set { defaults.set(newValue, forKey: "itemsPerFolder") }
    }

    static var totalFolderItems: Int {
        folderCount * itemsPerFolder
    }

    static var menuCharacterCount: Int {
        get {
            let val = defaults.integer(forKey: "menuCharacterCount")
            return val > 0 ? val : 50
        }
        set { defaults.set(newValue, forKey: "menuCharacterCount") }
    }

    static var pastingMovesToTop: Bool {
        get {
            defaults.object(forKey: "pastingMovesToTop") == nil ? true : defaults.bool(forKey: "pastingMovesToTop")
        }
        set { defaults.set(newValue, forKey: "pastingMovesToTop") }
    }

    static var tooltipLength: Int {
        get {
            let val = defaults.integer(forKey: "tooltipLength")
            return val > 0 ? val : 200
        }
        set { defaults.set(newValue, forKey: "tooltipLength") }
    }

    static var showInlineImages: Bool {
        get {
            defaults.object(forKey: "showInlineImages") == nil ? true : defaults.bool(forKey: "showInlineImages")
        }
        set { defaults.set(newValue, forKey: "showInlineImages") }
    }

    static var ignoredApps: [String] {
        get { defaults.stringArray(forKey: "ignoredApps") ?? [] }
        set { defaults.set(newValue, forKey: "ignoredApps") }
    }
}
