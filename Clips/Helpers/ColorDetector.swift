import AppKit

enum ColorDetector {
    private static let hexPattern = try! NSRegularExpression(
        pattern: #"^#([0-9a-fA-F]{3}|[0-9a-fA-F]{4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$"#
    )

    static func detectHexColor(in text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        guard hexPattern.firstMatch(in: trimmed, range: range) != nil else { return nil }
        return trimmed
    }

    static func colorSquare(hex: String, size: CGFloat = 14) -> NSImage? {
        guard let color = NSColor(hex: hex) else { return nil }
        let img = NSImage(size: NSSize(width: size, height: size))
        img.lockFocus()
        color.setFill()
        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2).fill()
        NSColor.separatorColor.setStroke()
        NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 2, yRadius: 2).stroke()
        img.unlockFocus()
        return img
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespaces)
        if h.hasPrefix("#") { h.removeFirst() }

        var rgb: UInt64 = 0
        guard Scanner(string: h).scanHexInt64(&rgb) else { return nil }

        switch h.count {
        case 3:
            self.init(
                red: CGFloat((rgb >> 8) & 0xF) / 15,
                green: CGFloat((rgb >> 4) & 0xF) / 15,
                blue: CGFloat(rgb & 0xF) / 15,
                alpha: 1
            )
        case 4:
            self.init(
                red: CGFloat((rgb >> 12) & 0xF) / 15,
                green: CGFloat((rgb >> 8) & 0xF) / 15,
                blue: CGFloat((rgb >> 4) & 0xF) / 15,
                alpha: CGFloat(rgb & 0xF) / 15
            )
        case 6:
            self.init(
                red: CGFloat((rgb >> 16) & 0xFF) / 255,
                green: CGFloat((rgb >> 8) & 0xFF) / 255,
                blue: CGFloat(rgb & 0xFF) / 255,
                alpha: 1
            )
        case 8:
            self.init(
                red: CGFloat((rgb >> 24) & 0xFF) / 255,
                green: CGFloat((rgb >> 16) & 0xFF) / 255,
                blue: CGFloat((rgb >> 8) & 0xFF) / 255,
                alpha: CGFloat(rgb & 0xFF) / 255
            )
        default:
            return nil
        }
    }
}
