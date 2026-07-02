import Foundation

enum Config {
    static let appName = "DocDash"
    static let repoOwner = "olimart"
    static let repoName = "docdash"

    /// Release tag under which docset archives and catalog.json are published.
    static let docsetsReleaseTag = "docsets"

    static var catalogURL: URL {
        if let override = UserDefaults.standard.string(forKey: "catalogURL"),
           let url = URL(string: override) {
            return url
        }
        return URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases/download/\(docsetsReleaseTag)/catalog.json")!
    }

    static var docsetsDirectory: URL {
        if let override = ProcessInfo.processInfo.environment["DOCDASH_DOCSETS_DIR"] {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent(appName, isDirectory: true)
            .appendingPathComponent("Docsets", isDirectory: true)
    }
}
