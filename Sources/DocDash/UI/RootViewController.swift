import AppKit

/// A transparent overlay that dims the content behind the results panel and
/// dismisses it when clicked (Dash-style).
private final class BackdropView: NSView {
    var onClick: (() -> Void)?

    override func mouseDown(with event: NSEvent) { onClick?() }
}

/// Hosts the documentation web view full-bleed, with the floating results panel
/// (and its dimming backdrop) overlaid on top.
final class RootViewController: NSViewController {
    let content = ContentViewController()
    let results = ResultsPanelController()
    private let backdrop = BackdropView()

    override func loadView() {
        let root = NSView()

        addChild(content)
        content.view.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(content.view)

        backdrop.translatesAutoresizingMaskIntoConstraints = false
        backdrop.wantsLayer = true
        backdrop.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.14).cgColor
        backdrop.isHidden = true
        backdrop.onClick = { [weak self] in self?.results.dismiss() }
        root.addSubview(backdrop)

        addChild(results)
        results.view.translatesAutoresizingMaskIntoConstraints = false
        results.view.isHidden = true
        root.addSubview(results.view)

        results.onVisibilityChange = { [weak self] visible in
            self?.backdrop.isHidden = !visible
        }

        // Panel width tracks the window (with side margins) but caps at 720 and
        // stays centered. No hard minimum here so it can never pin the window's
        // resizable width — the window's own minSize governs that.
        let panelWidth = results.view.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -48)
        panelWidth.priority = .defaultHigh

        NSLayoutConstraint.activate([
            content.view.topAnchor.constraint(equalTo: root.topAnchor),
            content.view.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            content.view.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            content.view.trailingAnchor.constraint(equalTo: root.trailingAnchor),

            backdrop.topAnchor.constraint(equalTo: root.topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            backdrop.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: root.trailingAnchor),

            results.view.topAnchor.constraint(equalTo: root.topAnchor, constant: 10),
            results.view.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            results.view.leadingAnchor.constraint(greaterThanOrEqualTo: root.leadingAnchor, constant: 24),
            results.view.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -24),
            panelWidth,
            results.view.widthAnchor.constraint(lessThanOrEqualToConstant: 720),
        ])

        self.view = root
    }
}
