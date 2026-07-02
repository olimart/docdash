import Foundation

/// Scans and manages the on-disk docset store.
/// Layout: <docsetsDirectory>/<identifier>/docset.json + index.json + content/
final class DocsetLibrary {
    static let shared = DocsetLibrary()
    static let didChange = Notification.Name("DocsetLibraryDidChange")

    private(set) var docsets: [InstalledDocset] = []
    let root: URL

    private let inactiveKey = "inactiveDocsets"

    init(root: URL = Config.docsetsDirectory) {
        self.root = root
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    var activeDocsets: [InstalledDocset] { docsets.filter(\.isActive) }

    func rescan(loadActiveIndexes: Bool = true) {
        let inactive = Set(UserDefaults.standard.stringArray(forKey: inactiveKey) ?? [])
        var found: [InstalledDocset] = []
        let fm = FileManager.default
        let level1 = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        for dir in level1 {
            guard (try? dir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
            if let docset = readDocset(at: dir, inactive: inactive) {
                found.append(docset)
            } else {
                // Allow one extra nesting level: <type>/<version>/docset.json
                let level2 = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
                for sub in level2 {
                    if let docset = readDocset(at: sub, inactive: inactive) {
                        found.append(docset)
                    }
                }
            }
        }
        found.sort {
            if $0.info.name != $1.info.name { return $0.info.name < $1.info.name }
            // Newest version first within a docset family.
            return $0.info.version.compare($1.info.version, options: .numeric) == .orderedDescending
        }
        // Preserve already-loaded indexes across rescans.
        let previous = Dictionary(uniqueKeysWithValues: docsets.map { ($0.info.identifier, $0) })
        docsets = found.map { fresh in
            guard let old = previous[fresh.info.identifier] else { return fresh }
            old.isActive = fresh.isActive
            return old
        }

        NotificationCenter.default.post(name: Self.didChange, object: self)

        if loadActiveIndexes {
            for docset in activeDocsets {
                docset.loadEntriesAsync {
                    NotificationCenter.default.post(name: Self.didChange, object: self)
                }
            }
        }
    }

    func setActive(_ active: Bool, for docset: InstalledDocset) {
        docset.isActive = active
        var inactive = Set(UserDefaults.standard.stringArray(forKey: inactiveKey) ?? [])
        if active {
            inactive.remove(docset.info.identifier)
            docset.loadEntriesAsync {
                NotificationCenter.default.post(name: Self.didChange, object: self)
            }
        } else {
            inactive.insert(docset.info.identifier)
        }
        UserDefaults.standard.set(Array(inactive), forKey: inactiveKey)
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }

    func remove(_ docset: InstalledDocset) throws {
        try FileManager.default.removeItem(at: docset.rootURL)
        rescan()
    }

    func isInstalled(identifier: String) -> Bool {
        docsets.contains { $0.info.identifier == identifier }
    }

    private func readDocset(at dir: URL, inactive: Set<String>) -> InstalledDocset? {
        let manifestURL = dir.appendingPathComponent("docset.json")
        guard let data = try? Data(contentsOf: manifestURL),
              let info = try? JSONDecoder().decode(DocsetInfo.self, from: data) else { return nil }
        return InstalledDocset(info: info, rootURL: dir, isActive: !inactive.contains(info.identifier))
    }
}
