import AppKit

/// "Docsets ▸ Manage Docsets…" — lists the catalog published on GitHub
/// Releases and installs/removes docsets.
final class ManageDocsetsWindowController: NSWindowController,
    NSTableViewDataSource, NSTableViewDelegate {

    private enum RowStatus {
        case notInstalled
        case installed
        case installing
        case failed(String)
    }

    private struct Row {
        var entry: CatalogEntry
        var status: RowStatus
    }

    private var rows: [Row] = []
    private let tableView = NSTableView()
    private let infoLabel = NSTextField(labelWithString: "Loading catalog…")

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Manage Docsets"
        window.center()
        super.init(window: window)

        let content = NSView()

        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.font = NSFont.systemFont(ofSize: 11)
        infoLabel.textColor = .secondaryLabelColor
        infoLabel.lineBreakMode = .byTruncatingTail
        content.addSubview(infoLabel)

        tableView.headerView = nil
        tableView.rowHeight = 44
        tableView.allowsEmptySelection = true
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.dataSource = self
        tableView.delegate = self

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        content.addSubview(scrollView)

        let refreshButton = NSButton(title: "Refresh", target: self, action: #selector(refresh(_:)))
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(refreshButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: infoLabel.topAnchor, constant: -8),

            infoLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14),
            infoLabel.trailingAnchor.constraint(lessThanOrEqualTo: refreshButton.leadingAnchor, constant: -8),
            infoLabel.centerYAnchor.constraint(equalTo: refreshButton.centerYAnchor),

            refreshButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            refreshButton.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -10),
        ])

        window.contentView = content

        NotificationCenter.default.addObserver(
            self, selector: #selector(libraryChanged),
            name: DocsetLibrary.didChange, object: nil
        )
        refresh(nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func libraryChanged() {
        for index in rows.indices {
            if case .installing = rows[index].status { continue }
            rows[index].status = DocsetLibrary.shared.isInstalled(identifier: rows[index].entry.identifier)
                ? .installed : .notInstalled
        }
        tableView.reloadData()
    }

    @objc private func refresh(_ sender: Any?) {
        infoLabel.stringValue = "Loading catalog…"
        DocsetInstaller.shared.fetchCatalog { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let catalog):
                self.rows = catalog.docsets.map { entry in
                    Row(entry: entry,
                        status: DocsetLibrary.shared.isInstalled(identifier: entry.identifier)
                            ? .installed : .notInstalled)
                }
                self.infoLabel.stringValue = "\(catalog.docsets.count) docsets available"
            case .failure(let error):
                self.rows = []
                self.infoLabel.stringValue = "Catalog unavailable (\(error.localizedDescription)). You can also drop docset folders into Docsets ▸ Open Docsets Folder."
            }
            self.tableView.reloadData()
        }
    }

    @objc private func actionClicked(_ sender: NSButton) {
        let index = sender.tag
        guard index >= 0, index < rows.count else { return }
        let entry = rows[index].entry
        switch rows[index].status {
        case .installed:
            if let docset = DocsetLibrary.shared.docsets.first(where: { $0.info.identifier == entry.identifier }) {
                try? DocsetLibrary.shared.remove(docset)
            }
        case .notInstalled, .failed:
            rows[index].status = .installing
            tableView.reloadData()
            DocsetInstaller.shared.install(entry) { [weak self] result in
                guard let self else { return }
                guard let currentIndex = self.rows.firstIndex(where: { $0.entry.identifier == entry.identifier }) else { return }
                switch result {
                case .success:
                    self.rows[currentIndex].status = .installed
                case .failure(let error):
                    self.rows[currentIndex].status = .failed(error.localizedDescription)
                }
                self.tableView.reloadData()
            }
        case .installing:
            break
        }
    }

    // MARK: - Table

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let rowModel = rows[row]
        let cell = NSTableCellView()

        let title = NSTextField(labelWithString: rowModel.entry.displayName)
        title.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        title.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(title)

        var subtitleText: String
        switch rowModel.status {
        case .notInstalled:
            subtitleText = rowModel.entry.sizeBytes.map { "≈\($0 / 1_000_000) MB" } ?? "not installed"
        case .installed: subtitleText = "installed"
        case .installing: subtitleText = "downloading…"
        case .failed(let reason): subtitleText = "failed: \(reason)"
        }
        let subtitle = NSTextField(labelWithString: subtitleText)
        subtitle.font = NSFont.systemFont(ofSize: 10)
        subtitle.textColor = .secondaryLabelColor
        subtitle.lineBreakMode = .byTruncatingTail
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(subtitle)

        let buttonTitle: String
        var buttonEnabled = true
        switch rowModel.status {
        case .installed: buttonTitle = "Remove"
        case .installing: buttonTitle = "Installing…"; buttonEnabled = false
        case .failed: buttonTitle = "Retry"
        case .notInstalled: buttonTitle = "Install"
        }
        let button = NSButton(title: buttonTitle, target: self, action: #selector(actionClicked(_:)))
        button.tag = row
        button.isEnabled = buttonEnabled
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(button)

        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
            title.topAnchor.constraint(equalTo: cell.topAnchor, constant: 5),
            title.trailingAnchor.constraint(lessThanOrEqualTo: button.leadingAnchor, constant: -8),

            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 2),
            subtitle.trailingAnchor.constraint(lessThanOrEqualTo: button.leadingAnchor, constant: -8),

            button.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            button.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 90),
        ])
        return cell
    }
}
