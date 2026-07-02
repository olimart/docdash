import AppKit

protocol SidebarDelegate: AnyObject {
    func sidebar(_ sidebar: SidebarViewController, didSelect result: SearchResult)
    func sidebar(_ sidebar: SidebarViewController, didSelectDocset docset: InstalledDocset)
}

/// Left column: search field on top, and below it either the list of installed
/// docsets (browse mode) or ranked search results (search mode) — Dash-style.
final class SidebarViewController: NSViewController,
    NSSearchFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {

    weak var delegate: SidebarDelegate?

    private enum Mode { case browse, results }
    private var mode: Mode = .browse

    private var searchField: NSSearchField?
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let manageButton = NSButton()
    private let engine = SearchEngine()
    private var results: [SearchResult] = []
    private var browseDocsets: [InstalledDocset] = []

    override func loadView() {
        let container = NSVisualEffectView()
        container.material = .sidebar
        container.blendingMode = .behindWindow

        tableView.headerView = nil
        tableView.rowHeight = 38
        tableView.style = .sourceList
        tableView.allowsEmptySelection = true
        tableView.allowsMultipleSelection = false
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.action = #selector(rowClicked(_:))

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        tableView.backgroundColor = .clear
        container.addSubview(scrollView)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail
        container.addSubview(statusLabel)

        // nil target: resolved via the responder chain to AppDelegate.
        manageButton.title = "Manage Docsets…"
        manageButton.target = nil
        manageButton.action = #selector(AppDelegate.showManageDocsets(_:))
        manageButton.isBordered = false
        manageButton.contentTintColor = .controlAccentColor
        manageButton.font = NSFont.systemFont(ofSize: 11)
        manageButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(manageButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -4),

            statusLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            statusLabel.bottomAnchor.constraint(equalTo: manageButton.topAnchor, constant: -3),

            manageButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            manageButton.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -12),
            manageButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
        ])

        self.view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(
            self, selector: #selector(libraryChanged),
            name: DocsetLibrary.didChange, object: nil
        )
        reloadBrowse()
    }

    /// Adopts the window's toolbar search field (Dash-style centered search).
    func installSearchField(_ field: NSSearchField) {
        searchField = field
        field.placeholderString = "Search — e.g. find_by or rails:find_by"
        field.delegate = self
        field.sendsSearchStringImmediately = true
        field.sendsWholeSearchString = false
    }

    func focusSearchField() {
        guard let searchField else { return }
        searchField.window?.makeFirstResponder(searchField)
    }

    /// Programmatic search — used by the --search debug/testing launch flag.
    func performSearch(_ query: String) {
        searchField?.stringValue = query
        runSearch()
    }

    // MARK: - Library

    @objc private func libraryChanged() {
        reloadBrowse()
        if mode == .results {
            runSearch()
        }
    }

    private func reloadBrowse() {
        browseDocsets = DocsetLibrary.shared.docsets
        if mode == .browse {
            tableView.reloadData()
            updateStatus()
        }
    }

    private func updateStatus() {
        switch mode {
        case .browse:
            let active = DocsetLibrary.shared.activeDocsets.count
            if browseDocsets.isEmpty {
                statusLabel.stringValue = "No docsets installed yet"
            } else {
                statusLabel.stringValue = "\(browseDocsets.count) docsets installed, \(active) active"
            }
        case .results:
            statusLabel.stringValue = "\(results.count) results"
        }
    }

    // MARK: - Search

    func controlTextDidChange(_ obj: Notification) {
        runSearch()
    }

    private func runSearch() {
        let query = (searchField?.stringValue ?? "").trimmingCharacters(in: .whitespaces)
        if query.isEmpty {
            mode = .browse
            results = []
            tableView.reloadData()
            updateStatus()
            return
        }
        engine.search(query: query, in: DocsetLibrary.shared) { [weak self] found in
            guard let self else { return }
            self.mode = .results
            self.results = found
            self.tableView.reloadData()
            if !found.isEmpty {
                self.tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                self.tableView.scrollRowToVisible(0)
                self.openSelection()
            }
            self.updateStatus()
        }
    }

    // Arrow keys / Enter from the search field drive the results list.
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.moveDown(_:)):
            moveSelection(by: 1)
            return true
        case #selector(NSResponder.moveUp(_:)):
            moveSelection(by: -1)
            return true
        case #selector(NSResponder.insertNewline(_:)):
            openSelection()
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            if let searchField, !searchField.stringValue.isEmpty {
                searchField.stringValue = ""
                runSearch()
                return true
            }
            return false
        default:
            return false
        }
    }

    private func moveSelection(by delta: Int) {
        let count = tableView.numberOfRows
        guard count > 0 else { return }
        var row = tableView.selectedRow + delta
        row = max(0, min(count - 1, row))
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        tableView.scrollRowToVisible(row)
        openSelection()
    }

    private func openSelection() {
        let row = tableView.selectedRow
        guard row >= 0 else { return }
        switch mode {
        case .results:
            guard row < results.count else { return }
            delegate?.sidebar(self, didSelect: results[row])
        case .browse:
            guard row < browseDocsets.count else { return }
            delegate?.sidebar(self, didSelectDocset: browseDocsets[row])
        }
    }

    @objc private func rowClicked(_ sender: Any?) {
        openSelection()
    }

    @objc private func toggleActive(_ sender: NSButton) {
        let row = sender.tag
        guard mode == .browse, row >= 0, row < browseDocsets.count else { return }
        DocsetLibrary.shared.setActive(sender.state == .on, for: browseDocsets[row])
    }

    // MARK: - Table

    func numberOfRows(in tableView: NSTableView) -> Int {
        mode == .browse ? browseDocsets.count : results.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        switch mode {
        case .browse:
            return browseCell(for: browseDocsets[row], row: row)
        case .results:
            return resultCell(for: results[row])
        }
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        // Only auto-open on selection when navigating results; browse rows
        // open on click/Enter to avoid loading pages while toggling checkboxes.
        if mode == .results {
            openSelection()
        }
    }

    private func browseCell(for docset: InstalledDocset, row: Int) -> NSView {
        let cell = NSTableCellView()

        let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleActive(_:)))
        checkbox.state = docset.isActive ? .on : .off
        checkbox.tag = row
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(checkbox)

        let title = NSTextField(labelWithString: docset.info.displayName)
        title.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        title.lineBreakMode = .byTruncatingTail
        title.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(title)

        let count = docset.entries.map { "\($0.count) entries" } ?? "\(docset.info.entryCount) entries"
        let subtitle = NSTextField(labelWithString: docset.isActive ? count : "inactive")
        subtitle.font = NSFont.systemFont(ofSize: 10)
        subtitle.textColor = .secondaryLabelColor
        subtitle.lineBreakMode = .byTruncatingTail
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(subtitle)

        NSLayoutConstraint.activate([
            checkbox.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            checkbox.centerYAnchor.constraint(equalTo: cell.centerYAnchor),

            title.leadingAnchor.constraint(equalTo: checkbox.trailingAnchor, constant: 6),
            title.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -8),
            title.topAnchor.constraint(equalTo: cell.topAnchor, constant: 3),

            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            subtitle.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -8),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 1),
        ])
        return cell
    }

    private func resultCell(for result: SearchResult) -> NSView {
        let cell = NSTableCellView()

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: result.entry.kind.symbolName,
                             accessibilityDescription: result.entry.kind.label)
        icon.contentTintColor = Self.tint(for: result.entry.kind)
        icon.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(icon)

        let title = NSTextField(labelWithString: result.entry.name)
        title.font = NSFont.systemFont(ofSize: 13)
        title.lineBreakMode = .byTruncatingTail
        title.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(title)

        let subtitleText = "\(result.entry.kind.label) — \(result.docset.info.displayName)"
        let subtitle = NSTextField(labelWithString: subtitleText)
        subtitle.font = NSFont.systemFont(ofSize: 10)
        subtitle.textColor = .secondaryLabelColor
        subtitle.lineBreakMode = .byTruncatingTail
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(subtitle)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
            icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18),

            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 7),
            title.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -8),
            title.topAnchor.constraint(equalTo: cell.topAnchor, constant: 3),

            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            subtitle.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -8),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 1),
        ])
        return cell
    }

    private static func tint(for kind: EntryKind) -> NSColor {
        switch kind {
        case .klass: return .systemBlue
        case .module: return .systemPurple
        case .instanceMethod: return .systemTeal
        case .classMethod: return .systemIndigo
        case .constant: return .systemOrange
        case .attribute: return .systemGreen
        case .guide, .other: return .systemGray
        }
    }
}
