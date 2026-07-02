import AppKit

final class MainWindowController: NSWindowController, NSToolbarDelegate, ResultsPanelDelegate {
    private let root = RootViewController()
    private let searchItem = NSSearchToolbarItem(itemIdentifier: .docDashSearch)

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1180, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = Config.appName
        window.minSize = NSSize(width: 520, height: 380)
        super.init(window: window)

        // Install the root view via contentView, NOT contentViewController:
        // assigning a contentViewController makes AppKit continuously resize the
        // window to the view's Auto Layout fitting size, which pinned the window
        // to a fixed width (you could shrink but not grow, and the saved frame
        // was ignored). contentView leaves the window's frame under our control.
        _ = root.view // force loadView so child controllers are wired up
        window.contentView = root.view
        window.center()
        window.setFrameAutosaveName("MainWindow")

        // Dash-style centered search field in the title bar.
        searchItem.preferredWidthForSearchField = 360
        let toolbar = NSToolbar(identifier: "MainToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        toolbar.centeredItemIdentifiers = [.docDashSearch]
        window.toolbar = toolbar
        window.toolbarStyle = .unified

        root.results.delegate = self
        root.results.installSearchField(searchItem.searchField)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc func focusSearch(_ sender: Any?) {
        root.results.focusSearchField()
    }

    func performSearch(_ query: String, openFirst: Bool = false) {
        root.results.performSearch(query, openFirst: openFirst)
    }

    // MARK: - NSToolbarDelegate

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, .docDashSearch, .flexibleSpace]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, .docDashSearch]
    }

    func toolbar(_ toolbar: NSToolbar,
                 itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        itemIdentifier == .docDashSearch ? searchItem : nil
    }

    // MARK: - ResultsPanelDelegate

    func resultsPanel(_ panel: ResultsPanelController, didChoose result: SearchResult, commit: Bool) {
        guard let url = result.docset.url(for: result.entry) else { return }
        root.content.load(url: url, readAccessURL: result.docset.rootURL)
        window?.title = "\(result.entry.name) — \(result.docset.info.displayName)"
    }
}

extension NSToolbarItem.Identifier {
    static let docDashSearch = NSToolbarItem.Identifier("DocDashSearch")
}
