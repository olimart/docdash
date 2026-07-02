import Foundation

/// Manifest stored at the root of every installed docset (docset.json).
/// This is the single common format all pipelines produce.
struct DocsetInfo: Codable {
    var format: Int
    var type: String        // pipeline type, e.g. "ruby", "rails"
    var name: String        // display name, e.g. "Ruby"
    var version: String     // e.g. "3.4.1"
    var identifier: String  // unique, e.g. "ruby-3.4.1"
    var indexPath: String   // relative path to index.json
    var contentRoot: String // relative path to the HTML tree
    var landingPage: String // relative to contentRoot
    var entryCount: Int
    var generatedAt: String?
    var source: String?

    var displayName: String { "\(name) \(version)" }
}

enum EntryKind: String {
    case klass = "c"
    case module = "o"
    case instanceMethod = "m"
    case classMethod = "M"
    case constant = "n"
    case attribute = "a"
    case guide = "f"
    case other = "?"

    var label: String {
        switch self {
        case .klass: return "Class"
        case .module: return "Module"
        case .instanceMethod: return "Method"
        case .classMethod: return "Class Method"
        case .constant: return "Constant"
        case .attribute: return "Attribute"
        case .guide: return "Guide"
        case .other: return "Entry"
        }
    }

    var symbolName: String {
        switch self {
        case .klass: return "c.square.fill"
        case .module: return "m.square.fill"
        case .instanceMethod: return "number.square.fill"
        case .classMethod: return "s.square.fill"
        case .constant: return "k.square.fill"
        case .attribute: return "a.square.fill"
        case .guide: return "doc.text.fill"
        case .other: return "square.fill"
        }
    }
}

/// One searchable entry. Serialized in index.json as ["Array#map", "m", "Array.html#method-i-map"].
struct IndexEntry {
    let name: String
    let kind: EntryKind
    let path: String
    let lowerName: String
    let lowerTail: String  // portion after the last "#" or "::", for method-first matching

    init(name: String, kind: EntryKind, path: String) {
        self.name = name
        self.kind = kind
        self.path = path
        self.lowerName = name.lowercased()
        if let range = lowerName.range(of: "#", options: .backwards) {
            self.lowerTail = String(lowerName[range.upperBound...])
        } else if let range = lowerName.range(of: "::", options: .backwards) {
            self.lowerTail = String(lowerName[range.upperBound...])
        } else {
            self.lowerTail = lowerName
        }
    }

    /// Containing class/module, if the name encodes one.
    var container: String? {
        if let range = name.range(of: "#", options: .backwards) {
            return String(name[..<range.lowerBound])
        }
        if let range = name.range(of: "::", options: .backwards) {
            return String(name[..<range.lowerBound])
        }
        return nil
    }

    /// The entry's own name without its container (e.g. "map" for "Array#map").
    var shortName: String {
        if let range = name.range(of: "#", options: .backwards) {
            return String(name[range.upperBound...])
        }
        if let range = name.range(of: "::", options: .backwards) {
            return String(name[range.upperBound...])
        }
        return name
    }
}

final class InstalledDocset {
    let info: DocsetInfo
    let rootURL: URL
    var isActive: Bool
    private(set) var entries: [IndexEntry]?
    private var loading = false

    init(info: DocsetInfo, rootURL: URL, isActive: Bool) {
        self.info = info
        self.rootURL = rootURL
        self.isActive = isActive
    }

    var contentRootURL: URL {
        rootURL.appendingPathComponent(info.contentRoot, isDirectory: true)
    }

    var landingPageURL: URL {
        contentRootURL.appendingPathComponent(info.landingPage)
    }

    /// Resolves an entry path (which may include a "#anchor") into a loadable file URL.
    func url(for entry: IndexEntry) -> URL? {
        let parts = entry.path.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        let fileURL = contentRootURL.appendingPathComponent(String(parts[0]))
        guard parts.count == 2, !parts[1].isEmpty else { return fileURL }
        var components = URLComponents(url: fileURL, resolvingAgainstBaseURL: false)
        components?.fragment = String(parts[1])
        return components?.url ?? fileURL
    }

    @discardableResult
    func loadEntriesSync() -> [IndexEntry] {
        if let entries { return entries }
        let indexURL = rootURL.appendingPathComponent(info.indexPath)
        var result: [IndexEntry] = []
        if let data = try? Data(contentsOf: indexURL),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let raw = object["entries"] as? [[Any]] {
            result.reserveCapacity(raw.count)
            for row in raw {
                guard row.count >= 3,
                      let name = row[0] as? String,
                      let kindCode = row[1] as? String,
                      let path = row[2] as? String else { continue }
                let kind = EntryKind(rawValue: kindCode) ?? .other
                result.append(IndexEntry(name: name, kind: kind, path: path))
            }
        }
        entries = result
        return result
    }

    func loadEntriesAsync(queue: DispatchQueue = .global(qos: .userInitiated),
                          completion: @escaping () -> Void) {
        guard entries == nil, !loading else { completion(); return }
        loading = true
        queue.async { [weak self] in
            self?.loadEntriesSync()
            DispatchQueue.main.async {
                self?.loading = false
                completion()
            }
        }
    }
}
