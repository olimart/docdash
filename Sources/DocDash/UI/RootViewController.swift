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

        // Panel prefers 720pt, capped there, centered. This preference must NOT
        // reference root.width: an equality tying panel width to root width makes
        // Auto Layout drive the *window* to 720+margins (you could shrink but not
        // grow). The leading/trailing margins alone shrink it on narrow windows.
        let panelWidth = results.view.widthAnchor.constraint(equalToConstant: 720)
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

        root.translatesAutoresizingMaskIntoConstraints = true

        self.view = root
    }
}
