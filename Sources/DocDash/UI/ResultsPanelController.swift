import AppKit

protocol ResultsPanelDelegate: AnyObject {
    /// A result was chosen (arrow-preview, click, or Enter). `commit` is true
    /// when the choice should dismiss the panel and reveal the full page.
    func resultsPanel(_ panel: ResultsPanelController, didChoose result: SearchResult, commit: Bool)
}

/// Dash-style floating results list shown under the centered search field.
/// Rows read as: [docset badge] [kind badge] name  source (dimmed).
final class ResultsPanelController: NSViewController,
    NSSearchFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {

    weak var delegate: ResultsPanelDelegate?
    var onVisibilityChange: ((Bool) -> Void)?

    private let headerLabel = NSTextField(labelWithString: "")
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let engine = SearchEngine()

    private var searchField: NSSearchField?
    private var results: [SearchResult] = []
    private var highlightNeedle = ""
    private var heightConstraint: NSLayoutConstraint!

    private let rowHeight: CGFloat = 30
    private let headerHeight: CGFloat = 28
    private let maxVisibleRows = 10

    override func loadView() {
        let container = NSVisualEffectView()
        container.material = .menu
        container.blendingMode = .behindWindow
        container.state = .active
        container.wantsLayer = true
        container.layer?.cornerRadius = 10
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor.separatorColor.cgColor
        container.layer?.masksToBounds = true
        container.shadow = NSShadow()

        headerLabel.font = .systemFont(ofSize: 11, weight: .medium)
        headerLabel.textColor = .secondaryLabelColor
        headerLabel.alignment = .center
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(headerLabel)

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(separator)

        tableView.headerView = nil
        tableView.rowHeight = rowHeight
        tableView.style = .fullWidth
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .regular
        tableView.allowsEmptySelection = true
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("result"))
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
        container.addSubview(scrollView)

        heightConstraint = container.heightAnchor.constraint(equalToConstant: headerHeight)

        NSLayoutConstraint.activate([
            heightConstraint,
            headerLabel.topAnchor.constraint(equalTo: container.topAnchor),
            headerLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            headerLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            headerLabel.heightAnchor.constraint(equalToConstant: headerHeight),

            separator.topAnchor.constraint(equalTo: headerLabel.bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: separator.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        self.view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(
            self, selector: #selector(libraryChanged),
            name: DocsetLibrary.didChange, object: nil
        )
    }

    // MARK: - Search field

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

    func performSearch(_ query: String) {
        searchField?.stringValue = query
        runSearch()
    }

    func dismiss() {
        setVisible(false)
    }

    // MARK: - Visibility

    private func setVisible(_ visible: Bool) {
        guard view.isHidden == visible else {
            if !visible { onVisibilityChange?(false) }
            view.isHidden = !visible
            return
        }
        view.isHidden = !visible
        onVisibilityChange?(visible)
    }

    // MARK: - Search

    func controlTextDidChange(_ obj: Notification) {
        runSearch()
    }

    private func runSearch() {
        let query = (searchField?.stringValue ?? "").trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            results = []
            setVisible(false)
            return
        }
        let docsets = DocsetLibrary.shared.activeDocsets
        highlightNeedle = SearchEngine.parseScope(query: query, docsets: docsets).1
        engine.search(query: query, in: DocsetLibrary.shared) { [weak self] found in
            guard let self else { return }
            self.results = found
            self.tableView.reloadData()
            self.updateHeader()
            self.updateHeight()
            if !found.isEmpty {
                self.tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                self.tableView.scrollRowToVisible(0)
            }
            self.setVisible(true)
        }
    }

    private func updateHeader() {
        switch results.count {
        case 0: headerLabel.stringValue = "No results"
        case 1: headerLabel.stringValue = "1 result"
        case engine.maxResults: headerLabel.stringValue = "\(engine.maxResults)+ results"
        default: headerLabel.stringValue = "\(results.count) results"
        }
    }

    private func updateHeight() {
        let visibleRows = min(max(results.count, 1), maxVisibleRows)
        let body = results.isEmpty ? rowHeight : CGFloat(visibleRows) * rowHeight
        heightConstraint.constant = headerHeight + 1 + body + 6
    }

    @objc private func libraryChanged() {
        if !view.isHidden { runSearch() }
    }

    // MARK: - Keyboard (routed from the search field's editor)

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.moveDown(_:)):
            moveSelection(by: 1)
            return true
        case #selector(NSResponder.moveUp(_:)):
            moveSelection(by: -1)
            return true
        case #selector(NSResponder.insertNewline(_:)):
            choose(row: tableView.selectedRow, commit: true)
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            if let searchField, !searchField.stringValue.isEmpty {
                searchField.stringValue = ""
                runSearch()
            } else {
                setVisible(false)
            }
            return true
        default:
            return false
        }
    }

    private func moveSelection(by delta: Int) {
        let count = tableView.numberOfRows
        guard count > 0 else { return }
        let row = max(0, min(count - 1, tableView.selectedRow + delta))
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        tableView.scrollRowToVisible(row)
        choose(row: row, commit: false)
    }

    private func choose(row: Int, commit: Bool) {
        guard row >= 0, row < results.count else { return }
        delegate?.resultsPanel(self, didChoose: results[row], commit: commit)
        if commit { setVisible(false) }
    }

    @objc private func rowClicked(_ sender: Any?) {
        choose(row: tableView.clickedRow, commit: true)
    }

    // MARK: - Table

    func numberOfRows(in tableView: NSTableView) -> Int { results.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        resultCell(for: results[row])
    }

    private func resultCell(for result: SearchResult) -> NSView {
        let cell = NSTableCellView()

        let docsetBadge = NSImageView(image: Badges.docset(type: result.docset.info.type))
        docsetBadge.toolTip = result.docset.info.displayName
        docsetBadge.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(docsetBadge)

        let kindBadge = NSImageView(image: Badges.kind(result.entry.kind))
        kindBadge.toolTip = result.entry.kind.label
        kindBadge.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(kindBadge)

        let name = NSTextField(labelWithAttributedString: highlightedName(result.entry))
        name.lineBreakMode = .byTruncatingTail
        name.setContentHuggingPriority(.required, for: .horizontal)
        name.setContentCompressionResistancePriority(.required, for: .horizontal)
        name.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(name)

        let source = NSTextField(labelWithString: result.entry.container ?? result.docset.info.name)
        source.font = .systemFont(ofSize: 12)
        source.textColor = .tertiaryLabelColor
        source.lineBreakMode = .byTruncatingTail
        source.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        source.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(source)

        NSLayoutConstraint.activate([
            docsetBadge.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 10),
            docsetBadge.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            docsetBadge.widthAnchor.constraint(equalToConstant: 22),
            docsetBadge.heightAnchor.constraint(equalToConstant: 16),

            kindBadge.leadingAnchor.constraint(equalTo: docsetBadge.trailingAnchor, constant: 6),
            kindBadge.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            kindBadge.widthAnchor.constraint(equalToConstant: 18),
            kindBadge.heightAnchor.constraint(equalToConstant: 18),

            name.leadingAnchor.constraint(equalTo: kindBadge.trailingAnchor, constant: 9),
            name.centerYAnchor.constraint(equalTo: cell.centerYAnchor),

            source.leadingAnchor.constraint(equalTo: name.trailingAnchor, constant: 10),
            source.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -12),
            source.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }

    /// Renders the short name, tinting the matched substring like Dash.
    private func highlightedName(_ entry: IndexEntry) -> NSAttributedString {
        let shortName = entry.shortName
        let attributed = NSMutableAttributedString(
            string: shortName,
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: NSColor.labelColor,
            ]
        )
        if !highlightNeedle.isEmpty,
           let range = shortName.lowercased().range(of: highlightNeedle) {
            let nsRange = NSRange(range, in: shortName)
            attributed.addAttribute(.foregroundColor, value: NSColor.controlAccentColor, range: nsRange)
        }
        return attributed
    }
}
