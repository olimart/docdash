import AppKit

final class MainWindowController: NSWindowController, SidebarDelegate, NSToolbarDelegate {
    private let sidebarController = SidebarViewController()
    private let contentController = ContentViewController()
    private let searchItem = NSSearchToolbarItem(itemIdentifier: .docDashSearch)

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1180, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = Config.appName
        window.minSize = NSSize(width: 760, height: 420)
        window.center()
        window.setFrameAutosaveName("MainWindow")
        super.init(window: window)

        let splitController = NSSplitViewController()
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarController)
        sidebarItem.minimumThickness = 260
        sidebarItem.maximumThickness = 420
        sidebarItem.canCollapse = true
        splitController.addSplitViewItem(sidebarItem)
        splitController.addSplitViewItem(NSSplitViewItem(viewController: contentController))
        window.contentViewController = splitController

        // Dash-style centered search field in the title bar.
        searchItem.preferredWidthForSearchField = 360
        let toolbar = NSToolbar(identifier: "MainToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        toolbar.centeredItemIdentifiers = [.docDashSearch]
        window.toolbar = toolbar
        window.toolbarStyle = .unified

        sidebarController.delegate = self
        sidebarController.installSearchField(searchItem.searchField)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc func focusSearch(_ sender: Any?) {
        sidebarController.focusSearchField()
    }

    func performSearch(_ query: String) {
        sidebarController.performSearch(query)
    }

    // MARK: - NSToolbarDelegate

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.toggleSidebar, .flexibleSpace, .docDashSearch, .flexibleSpace]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.toggleSidebar, .flexibleSpace, .docDashSearch]
    }

    func toolbar(_ toolbar: NSToolbar,
                 itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        itemIdentifier == .docDashSearch ? searchItem : nil
    }

    // MARK: - SidebarDelegate

    func sidebar(_ sidebar: SidebarViewController, didSelect result: SearchResult) {
        guard let url = result.docset.url(for: result.entry) else { return }
        contentController.load(url: url, readAccessURL: result.docset.rootURL)
        window?.title = "\(result.entry.name) — \(result.docset.info.displayName)"
    }

    func sidebar(_ sidebar: SidebarViewController, didSelectDocset docset: InstalledDocset) {
        contentController.load(url: docset.landingPageURL, readAccessURL: docset.rootURL)
        window?.title = "\(docset.info.displayName) — \(Config.appName)"
    }
}

extension NSToolbarItem.Identifier {
    static let docDashSearch = NSToolbarItem.Identifier("DocDashSearch")
}
