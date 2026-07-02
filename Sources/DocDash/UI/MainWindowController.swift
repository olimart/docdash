import AppKit

final class MainWindowController: NSWindowController, SidebarDelegate {
    private let sidebarController = SidebarViewController()
    private let contentController = ContentViewController()

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1180, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = Config.appName
        window.titlebarAppearsTransparent = false
        window.minSize = NSSize(width: 760, height: 420)
        window.center()
        window.setFrameAutosaveName("MainWindow")
        super.init(window: window)

        let splitController = NSSplitViewController()
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarController)
        sidebarItem.minimumThickness = 260
        sidebarItem.maximumThickness = 420
        sidebarItem.canCollapse = false
        splitController.addSplitViewItem(sidebarItem)
        splitController.addSplitViewItem(NSSplitViewItem(viewController: contentController))
        window.contentViewController = splitController

        sidebarController.delegate = self
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc func focusSearch(_ sender: Any?) {
        sidebarController.focusSearchField()
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
