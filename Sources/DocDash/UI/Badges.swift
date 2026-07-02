import AppKit

/// Draws the small colored badges shown in each search result row: a per-docset
/// badge (identifies the source docset, like Dash's docset icons) and a per-kind
/// badge (the type of occurrence — method, class, constant…).
enum Badges {
    private static var cache: [String: NSImage] = [:]

    static func kind(_ kind: EntryKind) -> NSImage {
        cached("k-\(kind.rawValue)") {
            rounded(text: letter(for: kind), color: color(for: kind),
                    size: NSSize(width: 18, height: 18), fontSize: 11, radius: 4)
        }
    }

    static func docset(type: String) -> NSImage {
        cached("d-\(type)") {
            rounded(text: abbrev(type), color: docsetColor(type),
                    size: NSSize(width: 22, height: 16), fontSize: 9.5, radius: 4)
        }
    }

    // MARK: - Kind styling

    private static func letter(for kind: EntryKind) -> String {
        switch kind {
        case .klass: return "C"
        case .module: return "M"
        case .instanceMethod: return "M"
        case .classMethod: return "S"
        case .constant: return "K"
        case .attribute: return "A"
        case .guide: return "P"
        case .other: return "?"
        }
    }

    private static func color(for kind: EntryKind) -> NSColor {
        switch kind {
        case .klass: return .systemBlue
        case .module: return .systemPurple
        case .instanceMethod: return .systemTeal
        case .classMethod: return .systemIndigo
        case .constant: return .systemOrange
        case .attribute: return .systemGreen
        case .guide, .other: return .systemGray
        }
    }

    // MARK: - Docset styling

    private static func abbrev(_ type: String) -> String {
        switch type {
        case "ruby": return "Ru"
        case "rails": return "Ra"
        case "fixture": return "Fx"
        default: return String(type.prefix(2)).capitalized
        }
    }

    private static func docsetColor(_ type: String) -> NSColor {
        switch type {
        case "ruby": return .systemRed
        case "rails": return .systemIndigo
        case "fixture": return .systemGray
        default:
            let palette: [NSColor] = [.systemTeal, .systemBlue, .systemGreen,
                                      .systemOrange, .systemPurple, .systemPink, .systemBrown]
            return palette[abs(type.hashValue) % palette.count]
        }
    }

    // MARK: - Drawing

    private static func cached(_ key: String, _ make: () -> NSImage) -> NSImage {
        if let hit = cache[key] { return hit }
        let image = make()
        cache[key] = image
        return image
    }

    private static func rounded(text: String, color: NSColor, size: NSSize,
                                fontSize: CGFloat, radius: CGFloat) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        let rect = NSRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        color.setFill()
        path.fill()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: NSColor.white,
        ]
        let string = text as NSString
        let textSize = string.size(withAttributes: attrs)
        string.draw(at: NSPoint(x: (size.width - textSize.width) / 2,
                                y: (size.height - textSize.height) / 2),
                    withAttributes: attrs)
        image.unlockFocus()
        return image
    }
}
