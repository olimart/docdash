import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowController: MainWindowController?
    private var manageWindowController: ManageDocsetsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = buildMenu()
        DocsetLibrary.shared.rescan()
        let controller = MainWindowController()
        mainWindowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)

        let arguments = CommandLine.arguments
        if let index = arguments.firstIndex(of: "--search"), index + 1 < arguments.count {
            let query = arguments[index + 1]
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak controller] in
                controller?.performSearch(query)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    // MARK: - Actions

    @objc func showManageDocsets(_ sender: Any?) {
        if manageWindowController == nil {
            manageWindowController = ManageDocsetsWindowController()
        }
        manageWindowController?.showWindow(nil)
        manageWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    @objc func openDocsetsFolder(_ sender: Any?) {
        NSWorkspace.shared.open(DocsetLibrary.shared.root)
    }

    @objc func reloadLibrary(_ sender: Any?) {
        DocsetLibrary.shared.rescan()
    }

    // MARK: - Menu

    private func buildMenu() -> NSMenu {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "About \(Config.appName)",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide \(Config.appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit \(Config.appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu
        fileMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Find", action: #selector(MainWindowController.focusSearch(_:)), keyEquivalent: "f")
        let focusItem = editMenu.addItem(withTitle: "Focus Search", action: #selector(MainWindowController.focusSearch(_:)), keyEquivalent: "l")
        focusItem.keyEquivalentModifierMask = [.command]

        let docsetsMenuItem = NSMenuItem()
        mainMenu.addItem(docsetsMenuItem)
        let docsetsMenu = NSMenu(title: "Docsets")
        docsetsMenuItem.submenu = docsetsMenu
        let manageItem = docsetsMenu.addItem(withTitle: "Manage Docsets…", action: #selector(showManageDocsets(_:)), keyEquivalent: "d")
        manageItem.target = self
        docsetsMenu.addItem(.separator())
        let openFolderItem = docsetsMenu.addItem(withTitle: "Open Docsets Folder", action: #selector(openDocsetsFolder(_:)), keyEquivalent: "")
        openFolderItem.target = self
        let reloadItem = docsetsMenu.addItem(withTitle: "Reload Library", action: #selector(reloadLibrary(_:)), keyEquivalent: "r")
        reloadItem.target = self

        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        NSApp.windowsMenu = windowMenu

        return mainMenu
    }
}
