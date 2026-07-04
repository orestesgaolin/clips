import SwiftUI
import Carbon.HIToolbox

struct ShortcutRecorderView: View {
    /// When true, an empty (unset) shortcut is allowed and a clear button is shown.
    let allowsClear: Bool
    let load: () -> (code: UInt32?, modifiers: UInt32)
    let store: (UInt32?, UInt32) -> Void

    @State private var isRecording = false
    @State private var keyCode: UInt32?
    @State private var modifiers: UInt32

    init(
        allowsClear: Bool = false,
        load: @escaping () -> (code: UInt32?, modifiers: UInt32),
        store: @escaping (UInt32?, UInt32) -> Void
    ) {
        self.allowsClear = allowsClear
        self.load = load
        self.store = store
        let initial = load()
        _keyCode = State(initialValue: initial.code)
        _modifiers = State(initialValue: initial.modifiers)
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(isRecording ? "Press shortcut..." : displayString)
                .frame(minWidth: 120)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isRecording ? Color.accentColor.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isRecording ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: 1)
                )
                .onTapGesture { isRecording = true }

            if isRecording {
                Button("Cancel") { isRecording = false }
                    .controlSize(.small)
            } else if allowsClear, keyCode != nil {
                Button {
                    keyCode = nil
                    modifiers = 0
                    store(nil, 0)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .help("Clear shortcut")
            }
        }
        .background(isRecording ? ShortcutCaptureView(
            onCapture: { code, mods in
                let newCode = UInt32(code)
                let newModifiers = carbonModifiers(from: mods)
                keyCode = newCode
                modifiers = newModifiers
                store(newCode, newModifiers)
                isRecording = false
            },
            onCancel: { isRecording = false }
        ) : nil)
    }

    private var displayString: String {
        guard let keyCode else { return "None" }
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("\u{2303}") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("\u{2325}") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("\u{21E7}") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("\u{2318}") }
        parts.append(keyName(for: keyCode))
        return parts.joined()
    }
}

private struct ShortcutCaptureView: NSViewRepresentable {
    let onCapture: (UInt16, NSEvent.ModifierFlags) -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> ShortcutCaptureNSView {
        let view = ShortcutCaptureNSView()
        view.onCapture = onCapture
        view.onCancel = onCancel
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }

    func updateNSView(_ nsView: ShortcutCaptureNSView, context: Context) {}
}

private class ShortcutCaptureNSView: NSView {
    var onCapture: ((UInt16, NSEvent.ModifierFlags) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            onCancel?()
            return
        }
        let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard !mods.isEmpty else { return }
        onCapture?(event.keyCode, mods)
    }
}

private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
    var carbon: UInt32 = 0
    if flags.contains(.command) { carbon |= UInt32(cmdKey) }
    if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
    if flags.contains(.option) { carbon |= UInt32(optionKey) }
    if flags.contains(.control) { carbon |= UInt32(controlKey) }
    return carbon
}

private func keyName(for keyCode: UInt32) -> String {
    let names: [UInt32: String] = [
        UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B", UInt32(kVK_ANSI_C): "C",
        UInt32(kVK_ANSI_D): "D", UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F",
        UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H", UInt32(kVK_ANSI_I): "I",
        UInt32(kVK_ANSI_J): "J", UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
        UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N", UInt32(kVK_ANSI_O): "O",
        UInt32(kVK_ANSI_P): "P", UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R",
        UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T", UInt32(kVK_ANSI_U): "U",
        UInt32(kVK_ANSI_V): "V", UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
        UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z",
        UInt32(kVK_ANSI_0): "0", UInt32(kVK_ANSI_1): "1", UInt32(kVK_ANSI_2): "2",
        UInt32(kVK_ANSI_3): "3", UInt32(kVK_ANSI_4): "4", UInt32(kVK_ANSI_5): "5",
        UInt32(kVK_ANSI_6): "6", UInt32(kVK_ANSI_7): "7", UInt32(kVK_ANSI_8): "8",
        UInt32(kVK_ANSI_9): "9",
        UInt32(kVK_Space): "Space", UInt32(kVK_Return): "Return", UInt32(kVK_Tab): "Tab",
        UInt32(kVK_Delete): "Delete", UInt32(kVK_ForwardDelete): "Fwd Delete",
        UInt32(kVK_LeftArrow): "\u{2190}", UInt32(kVK_RightArrow): "\u{2192}",
        UInt32(kVK_UpArrow): "\u{2191}", UInt32(kVK_DownArrow): "\u{2193}",
        UInt32(kVK_Home): "Home", UInt32(kVK_End): "End",
        UInt32(kVK_PageUp): "Page Up", UInt32(kVK_PageDown): "Page Down",
        UInt32(kVK_F1): "F1", UInt32(kVK_F2): "F2", UInt32(kVK_F3): "F3",
        UInt32(kVK_F4): "F4", UInt32(kVK_F5): "F5", UInt32(kVK_F6): "F6",
        UInt32(kVK_F7): "F7", UInt32(kVK_F8): "F8", UInt32(kVK_F9): "F9",
        UInt32(kVK_F10): "F10", UInt32(kVK_F11): "F11", UInt32(kVK_F12): "F12",
        UInt32(kVK_ANSI_Minus): "-", UInt32(kVK_ANSI_Equal): "=",
        UInt32(kVK_ANSI_LeftBracket): "[", UInt32(kVK_ANSI_RightBracket): "]",
        UInt32(kVK_ANSI_Backslash): "\\", UInt32(kVK_ANSI_Semicolon): ";",
        UInt32(kVK_ANSI_Quote): "'", UInt32(kVK_ANSI_Comma): ",",
        UInt32(kVK_ANSI_Period): ".", UInt32(kVK_ANSI_Slash): "/",
        UInt32(kVK_ANSI_Grave): "`",
    ]
    return names[keyCode] ?? "Key \(keyCode)"
}
