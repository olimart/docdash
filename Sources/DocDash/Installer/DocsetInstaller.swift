import Foundation

struct CatalogEntry: Codable {
    var type: String
    var name: String
    var version: String
    var identifier: String
    var url: String
    var sizeBytes: Int?

    var displayName: String { "\(name) \(version)" }
}

struct Catalog: Codable {
    var format: Int
    var docsets: [CatalogEntry]
}

enum InstallerError: LocalizedError {
    case badCatalog
    case downloadFailed(String)
    case extractFailed(String)

    var errorDescription: String? {
        switch self {
        case .badCatalog: return "Could not read the docset catalog."
        case .downloadFailed(let reason): return "Download failed: \(reason)"
        case .extractFailed(let reason): return "Could not extract the docset archive: \(reason)"
        }
    }
}

/// Downloads docset archives listed in catalog.json and extracts them
/// into the library folder using the system tar (no third-party code).
final class DocsetInstaller {
    static let shared = DocsetInstaller()

    func fetchCatalog(completion: @escaping (Result<Catalog, Error>) -> Void) {
        let task = URLSession.shared.dataTask(with: Config.catalogURL) { data, _, error in
            DispatchQueue.main.async {
                if let error {
                    completion(.failure(error))
                    return
                }
                guard let data, let catalog = try? JSONDecoder().decode(Catalog.self, from: data) else {
                    completion(.failure(InstallerError.badCatalog))
                    return
                }
                completion(.success(catalog))
            }
        }
        task.resume()
    }

    func install(_ entry: CatalogEntry, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: entry.url) else {
            completion(.failure(InstallerError.downloadFailed("invalid URL")))
            return
        }
        let task = URLSession.shared.downloadTask(with: url) { tempURL, response, error in
            let finish: (Result<Void, Error>) -> Void = { result in
                DispatchQueue.main.async {
                    if case .success = result {
                        DocsetLibrary.shared.rescan()
                    }
                    completion(result)
                }
            }
            if let error {
                finish(.failure(InstallerError.downloadFailed(error.localizedDescription)))
                return
            }
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                finish(.failure(InstallerError.downloadFailed("HTTP \(http.statusCode)")))
                return
            }
            guard let tempURL else {
                finish(.failure(InstallerError.downloadFailed("no data")))
                return
            }
            do {
                try Self.extract(archive: tempURL, into: DocsetLibrary.shared.root)
                finish(.success(()))
            } catch {
                finish(.failure(error))
            }
        }
        task.resume()
    }

    static func extract(archive: URL, into destination: URL) throws {
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-xzf", archive.path, "-C", destination.path]
        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            throw InstallerError.extractFailed(String(data: data, encoding: .utf8) ?? "tar exited \(process.terminationStatus)")
        }
    }
}
