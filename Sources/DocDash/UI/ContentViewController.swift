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
    /* Suppress rdoc's heavy left bar on the targeted method/heading; the active
       method is marked in the sidebar instead (Dash-style). */
    main .method-detail:target,
    main h1:target, main h2:target, main h3:target,
    main h4:target, main h5:target, main h6:target,
    .legacy-anchor:target + h1, .legacy-anchor:target + h2,
    .legacy-anchor:target + h3, .legacy-anchor:target + h4,
    .legacy-anchor:target + h5, .legacy-anchor:target + h6 {
      margin-left: 0 !important;
      border-left: 0 !important;
    }
    /* Make the sidebar width responsive and keep the content offset by it at
       every window width. darkfish only offsets main above 1024px, so when
       narrow the fixed sidebar overlapped and clipped the content's left edge.
       Redefining --sidebar-width keeps the fixed nav and the content margin in
       lockstep, so both panes shrink together. */
    :root { --sidebar-width: clamp(150px, 26vw, 300px) !important; }
    /* darkfish hides the sidebar below 1024px (meant to be toggled by the
       hamburger, which we hide); force it visible so it's a persistent pane. */
    nav, #navigation { display: flex !important; }
    main { margin-left: var(--sidebar-width) !important; }
    /* Active method highlight in the sidebar method lists. */
    .link-list li.docdash-active {
      background: rgba(128, 128, 128, 0.22);
      border-radius: 6px;
    }
    .link-list li.docdash-active a { font-weight: 600; }
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

          // Mark the sidebar method link matching the current anchor as active.
          function mark() {
            var hash = location.hash;
            var links = document.querySelectorAll('.link-list a');
            for (var i = 0; i < links.length; i++) {
              var li = links[i].closest('li');
              if (!li) continue;
              if (hash && links[i].getAttribute('href') === hash) {
                li.classList.add('docdash-active');
                li.scrollIntoView({ block: 'nearest' });
              } else {
                li.classList.remove('docdash-active');
              }
            }
          }
          window.addEventListener('hashchange', mark);
          document.addEventListener('DOMContentLoaded', mark);
          mark();
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
