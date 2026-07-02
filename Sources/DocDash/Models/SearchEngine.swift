import Foundation

struct SearchResult {
    let docset: InstalledDocset
    let entry: IndexEntry
    let score: Int
}

/// Ranked substring search over the active docsets' indexes.
/// Runs on a background queue; only the latest query's results are delivered.
final class SearchEngine {
    private let queue = DispatchQueue(label: "docdash.search", qos: .userInitiated)
    private var generation = 0
    var maxResults = 300

    func search(query: String, in library: DocsetLibrary, completion: @escaping ([SearchResult]) -> Void) {
        generation += 1
        let current = generation
        let docsets = library.activeDocsets
        queue.async { [weak self] in
            guard let self else { return }
            let results = Self.searchSync(query: query, docsets: docsets, maxResults: self.maxResults)
            DispatchQueue.main.async {
                guard current == self.generation else { return }
                completion(results)
            }
        }
    }

    static func searchSync(query: String, docsets: [InstalledDocset], maxResults: Int = 300) -> [SearchResult] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return [] }
        var results: [SearchResult] = []
        for docset in docsets {
            guard let entries = docset.entries else { continue }
            for entry in entries {
                guard let score = score(entry: entry, needle: needle) else { continue }
                results.append(SearchResult(docset: docset, entry: entry, score: score))
            }
        }
        results.sort {
            if $0.score != $1.score { return $0.score < $1.score }
            if $0.entry.name.count != $1.entry.name.count { return $0.entry.name.count < $1.entry.name.count }
            return $0.entry.name < $1.entry.name
        }
        if results.count > maxResults {
            results.removeLast(results.count - maxResults)
        }
        return results
    }

    /// Lower is better; nil means no match.
    private static func score(entry: IndexEntry, needle: String) -> Int? {
        if entry.lowerTail == needle { return 0 }
        if entry.lowerName == needle { return 1 }
        if entry.lowerTail.hasPrefix(needle) { return 2 }
        if entry.lowerName.hasPrefix(needle) { return 3 }
        if entry.lowerTail.contains(needle) { return 4 }
        if entry.lowerName.contains(needle) { return 5 }
        return nil
    }
}
