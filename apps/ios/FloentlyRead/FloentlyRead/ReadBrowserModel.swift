import Foundation
import WebKit

@MainActor
final class ReadBrowserController: ObservableObject {
    @Published var addressText: String = ""
    @Published var currentURL: URL?
    @Published var pageTitle: String = ""
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false
    @Published var estimatedProgress: Double = 0
    @Published var readingStatus = "Ready"
    @Published var extractedText: String = ""
    @Published var selectionText: String = ""

    weak var webView: WKWebView?
    private var pendingURL: URL?

    static let protectedAuthenticationHosts: Set<String> = [
        "accounts.google.com",
        "login.microsoftonline.com",
        "login.live.com",
        "appleid.apple.com",
        "www.facebook.com",
        "m.facebook.com"
    ]

    func attach(_ webView: WKWebView) {
        self.webView = webView
        if let pendingURL {
            self.pendingURL = nil
            load(url: pendingURL)
        }
    }

    func open(_ input: String) {
        guard let url = Self.normalizeAddress(input) else {
            readingStatus = "Enter a valid website address or search term."
            return
        }
        load(url: url)
    }

    func open(url: URL) {
        guard let resolved = Self.resolveIncomingURL(url) ?? Self.normalizeAddress(url.absoluteString) else {
            readingStatus = "That link cannot be opened."
            return
        }
        load(url: resolved)
    }

    func load(url: URL) {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            readingStatus = "Only web pages can be loaded in the Read browser."
            return
        }

        addressText = url.absoluteString
        currentURL = url
        extractedText = ""
        selectionText = ""
        readingStatus = "Loading…"

        guard let webView else {
            pendingURL = url
            return
        }

        webView.load(URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 60))
    }

    func goBack() {
        webView?.goBack()
    }

    func goForward() {
        webView?.goForward()
    }

    func reload() {
        webView?.reload()
    }

    func stopLoading() {
        webView?.stopLoading()
    }

    func refreshNavigationState(from webView: WKWebView) {
        currentURL = webView.url
        addressText = webView.url?.absoluteString ?? addressText
        pageTitle = webView.title ?? ""
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        isLoading = webView.isLoading
        estimatedProgress = webView.estimatedProgress
    }

    func readPage() {
        guard let webView, let url = webView.url else { return }
        guard !Self.isProtectedAuthenticationURL(url) else {
            readingStatus = "Finish signing in before using Read on this page."
            return
        }

        readingStatus = "Finding the main reading area…"
        webView.evaluateJavaScript(Self.pageExtractionJavaScript) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.readingStatus = "Could not read this page: \(error.localizedDescription)"
                    return
                }
                guard
                    let json = result as? String,
                    let data = json.data(using: .utf8),
                    let payload = try? JSONDecoder().decode(ReadBrowserExtraction.self, from: data),
                    !payload.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else {
                    self.readingStatus = "No readable lesson or article text was found on the visible page."
                    return
                }

                self.extractedText = payload.text
                self.pageTitle = payload.title.isEmpty ? self.pageTitle : payload.title
                self.readingStatus = "Ready to read \(payload.wordCount) words from the live page."
            }
        }
    }

    func readSelection() {
        guard let webView, let url = webView.url else { return }
        guard !Self.isProtectedAuthenticationURL(url) else {
            readingStatus = "Finish signing in before using Read on this page."
            return
        }

        webView.evaluateJavaScript(Self.selectionExtractionJavaScript) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.readingStatus = "Could not read the selection: \(error.localizedDescription)"
                    return
                }
                let text = (result as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                self.selectionText = text
                self.readingStatus = text.isEmpty ? "Select text on the page first." : "Selection ready to read."
            }
        }
    }

    static func isProtectedAuthenticationURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return protectedAuthenticationHosts.contains(host)
            || host.hasSuffix(".okta.com")
            || host.hasSuffix(".auth0.com")
    }

    static func normalizeAddress(_ value: String) -> URL? {
        let raw = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        if let url = URL(string: raw), ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            return url
        }

        if raw.range(of: #"^[A-Za-z0-9.-]+\.[A-Za-z]{2,}([/:?#].*)?$"#, options: .regularExpression) != nil {
            return URL(string: "https://\(raw)")
        }

        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: raw)]
        return components?.url
    }

    static func resolveIncomingURL(_ incoming: URL) -> URL? {
        if incoming.scheme?.lowercased() == "floentlyread", incoming.host?.lowercased() == "open" {
            return URLComponents(url: incoming, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "url" })?.value
                .flatMap(normalizeAddress)
        }

        if ["http", "https"].contains(incoming.scheme?.lowercased() ?? ""),
           incoming.host?.lowercased() == "read.floently.com",
           incoming.path == "/mobile/open" {
            return URLComponents(url: incoming, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "url" })?.value
                .flatMap(normalizeAddress)
        }

        return ["http", "https"].contains(incoming.scheme?.lowercased() ?? "") ? incoming : nil
    }

    private static let selectionExtractionJavaScript = #"""
    (() => {
      const selection = window.getSelection();
      return String(selection ? selection.toString() : "")
        .replace(/\s+/g, " ")
        .trim();
    })();
    """#

    private static let pageExtractionJavaScript = #"""
    (() => {
      const normalize = (value) => String(value || "").replace(/\s+/g, " ").trim();
      const excludedSelector = [
        "script", "style", "noscript", "template", "nav", "footer", "aside",
        "[role='navigation']", "[role='dialog']", "[role='menu']", "[aria-modal='true']",
        "[aria-hidden='true']", "[hidden]", ".cookie", ".cookies", ".modal", ".drawer",
        ".sidebar", ".side-nav", ".sidenav", ".toolbar", ".menu"
      ].join(",");

      const isVisible = (element) => {
        if (!(element instanceof HTMLElement)) return false;
        const style = getComputedStyle(element);
        if (style.display === "none" || style.visibility === "hidden" || Number(style.opacity) === 0) return false;
        const rect = element.getBoundingClientRect();
        if (rect.width < 80 || rect.height < 24) return false;
        if (rect.bottom < 0 || rect.top > innerHeight * 1.5) return false;
        return true;
      };

      const exposure = (element) => {
        const rect = element.getBoundingClientRect();
        const points = [
          [rect.left + rect.width * 0.5, rect.top + Math.min(rect.height * 0.25, innerHeight * 0.25)],
          [rect.left + rect.width * 0.5, rect.top + Math.min(rect.height * 0.5, innerHeight * 0.5)]
        ];
        let hits = 0;
        for (const [x, y] of points) {
          if (x < 0 || y < 0 || x > innerWidth || y > innerHeight) continue;
          const stack = document.elementsFromPoint(x, y);
          if (stack.some((node) => node === element || element.contains(node))) hits += 1;
        }
        return hits;
      };

      const candidates = Array.from(document.querySelectorAll([
        "main", "article", "[role='main']", "[data-testid*='lesson' i]", "[data-testid*='content' i]",
        "[class*='lesson' i]", "[class*='lecture' i]", "[class*='transcript' i]", "[class*='content' i]",
        "section", "body"
      ].join(",")));

      const scored = candidates
        .filter(isVisible)
        .map((element) => {
          const clone = element.cloneNode(true);
          clone.querySelectorAll(excludedSelector).forEach((node) => node.remove());
          const text = normalize(clone.innerText || clone.textContent || "");
          if (text.length < 80) return null;

          const rect = element.getBoundingClientRect();
          const linkText = Array.from(element.querySelectorAll("a")).reduce((sum, link) => sum + normalize(link.innerText).length, 0);
          const controls = element.querySelectorAll("button,input,select,textarea,[role='button'],[role='menuitem']").length;
          const linkDensity = Math.min(1, linkText / Math.max(text.length, 1));
          const edgeDistance = Math.min(Math.abs(rect.left), Math.abs(innerWidth - rect.right));
          const narrowEdgePenalty = rect.width < innerWidth * 0.42 && edgeDistance < 40 ? 2500 : 0;
          const shellPenalty = element === document.body ? 1800 : 0;
          const fixedPenalty = ["fixed", "sticky"].includes(getComputedStyle(element).position) ? 1400 : 0;
          const semanticBonus = element.matches("main,article,[role='main']") ? 1800 : 0;
          const lessonBonus = /lesson|lecture|transcript|content/i.test(`${element.id} ${element.className}`) ? 900 : 0;
          const exposedBonus = exposure(element) * 800;
          const viewportWidthBonus = rect.width >= innerWidth * 0.45 && rect.width <= innerWidth * 0.98 ? 500 : 0;
          const score = Math.min(text.length, 14000) + semanticBonus + lessonBonus + exposedBonus + viewportWidthBonus
            - linkDensity * 7000 - controls * 55 - narrowEdgePenalty - shellPenalty - fixedPenalty;

          return { element, text, score };
        })
        .filter(Boolean)
        .sort((a, b) => b.score - a.score);

      const best = scored[0];
      const text = best ? best.text : "";
      return JSON.stringify({
        title: normalize(document.title),
        url: location.href,
        text,
        wordCount: text ? text.split(/\s+/).length : 0
      });
    })();
    """#
}

private struct ReadBrowserExtraction: Decodable {
    let title: String
    let url: String
    let text: String
    let wordCount: Int
}
