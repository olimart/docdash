import AppKit
import WebKit

/// Right column: renders docset HTML. External links open in the default browser.
final class ContentViewController: NSViewController, WKNavigationDelegate {
    private var webView: WKWebView!
    private let placeholder = NSTextField(labelWithString: "Select a docset or search for a method")

    override func loadView() {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(webView)

        placeholder.font = NSFont.systemFont(ofSize: 15)
        placeholder.textColor = .tertiaryLabelColor
        placeholder.alignment = .center
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(placeholder)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            placeholder.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            placeholder.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        webView.isHidden = true
        self.view = container
    }

    func load(url: URL, readAccessURL: URL) {
        placeholder.isHidden = true
        webView.isHidden = false
        webView.loadFileURL(url, allowingReadAccessTo: readAccessURL)
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url,
           let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
}
