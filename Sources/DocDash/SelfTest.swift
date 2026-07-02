import Foundation

/// Headless smoke test used by CI:
///   DocDash --selftest [--query NAME] [--expect-docsets N] [--expect-results]
/// Honors DOCDASH_DOCSETS_DIR to point at a fixture library.
func runSelfTest(arguments: [String]) -> Int32 {
    func value(after flag: String) -> String? {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    let library = DocsetLibrary.shared
    library.rescan(loadActiveIndexes: false)
    print("docsets dir: \(library.root.path)")
    print("docsets found: \(library.docsets.count)")
    for docset in library.docsets {
        let entries = docset.loadEntriesSync()
        print("  - \(docset.info.identifier): \(entries.count) entries (active: \(docset.isActive))")
    }

    if let expected = value(after: "--expect-docsets").flatMap({ Int($0) }),
       library.docsets.count < expected {
        print("FAIL: expected at least \(expected) docsets")
        return 1
    }

    if let query = value(after: "--query") {
        let results = SearchEngine.searchSync(query: query, docsets: library.activeDocsets, maxResults: 10)
        print("query \"\(query)\": \(results.count) results")
        for result in results {
            print("  \(result.entry.kind.label): \(result.entry.name) -> \(result.entry.path) [\(result.docset.info.identifier)]")
        }
        if arguments.contains("--expect-results") && results.isEmpty {
            print("FAIL: expected results for \"\(query)\"")
            return 1
        }
        if let first = results.first {
            let parts = first.entry.path.split(separator: "#", maxSplits: 1)
            let fileURL = first.docset.contentRootURL.appendingPathComponent(String(parts[0]))
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                print("FAIL: content file missing: \(fileURL.path)")
                return 1
            }
            print("content file OK: \(fileURL.lastPathComponent)")
        }
    }

    print("selftest OK")
    return 0
}
