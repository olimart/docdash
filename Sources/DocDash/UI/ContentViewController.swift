import AppKit
import WebKit

/// Right column: renders docset HTML. External links open in the default browser.
/// Injects CSS into every page to (a) follow the system light/dark appearance by
/// overriding darkfish's :root variables, and (b) hide rdoc's own responsive
/// navigation hamburger — the app's sidebar replaces it.
final class ContentViewController: NSViewController, WKNavigationDelegate {
    private var webView: WKWebView!
    private let placeholder = NSTextField(labelWithString: "Press ⌘L to search — install docsets via Docsets ▸ Manage Docsets…")

    private static let injectedCSS = """
    :root { color-scheme: light dark; }
    /* Strip rdoc's global chrome so only the class's own method navigation and
       the documentation content remain (Dash-style). The method-list sections
       and main content are left intact. */
    #navigation-toggle,
    #home-section,
    #table-of-contents-navigation,
    #search-section,
    #validator-badges { display: none !important; }
    @media (prefers-color-scheme: dark) {
      :root {
        --highlight-color: #ff6e63;
        --secondary-highlight-color: #ff8a9d;
        --text-color: #d8d8d8;
        --background-color: #1d1d1f;
        --code-block-background-color: #2a2a2e;
        --link-color: #a8b8ff;
        --border-color: #3a3a3e;
        --scrollbar-thumb-hover-background: #8a8a8a;
        --table-header-background-color: #2c2c31;
        --table-td-background-color: #26262a;
      }
      .ruby-constant   { color: #f4a261; }
      .ruby-keyword    { color: #ff7b72; }
      .ruby-ivar       { color: #e3b341; }
      .ruby-operator   { color: #8fd3b6; }
      .ruby-identifier { color: #79c0ff; }
      .ruby-node       { color: #d2a8ff; }
      .ruby-comment    { color: #9a9a8f; }
      .ruby-regexp     { color: #d2a8ff; }
      .ruby-value      { color: #f4a261; }
      .ruby-string     { color: #a5d6a7; }
      img { opacity: 0.9; }
    }
    """

    override func loadView() {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let source = """
        (function() {
          var style = document.createElement('style');
          style.textContent = \(Self.jsStringLiteral(Self.injectedCSS));
          document.documentElement.appendChild(style);
        })();
        """
        // documentEnd so the style element lands after the page's own
        // stylesheets in the cascade — the variable overrides must win.
        let script = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        configuration.userContentController.addUserScript(script)

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.underPageBackgroundColor = .textBackgroundColor
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

    /// Serializes a string as a JS string literal (JSON is valid JS).
    private static func jsStringLiteral(_ string: String) -> String {
        let data = try? JSONSerialization.data(withJSONObject: [string])
        let json = data.flatMap { String(data: $0, encoding: .utf8) } ?? "[\"\"]"
        return String(json.dropFirst().dropLast())
    }
}
