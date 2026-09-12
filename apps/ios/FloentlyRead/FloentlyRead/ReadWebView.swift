import SwiftUI
import WebKit

struct ReadWebView: UIViewRepresentable {
    @ObservedObject var controller: ReadBrowserController

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = [.audio, .video]

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.keyboardDismissMode = .interactive
        webView.isOpaque = true

        context.coordinator.observe(webView)
        controller.attach(webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        controller.refreshNavigationState(from: webView)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private weak var controller: ReadBrowserController?
        private var observations: [NSKeyValueObservation] = []

        init(controller: ReadBrowserController) {
            self.controller = controller
        }

        deinit {
            observations.forEach { $0.invalidate() }
        }

        func observe(_ webView: WKWebView) {
            let keyPaths: [KeyPath<WKWebView, Any>] = []
            _ = keyPaths

            observations = [
                webView.observe(\.url, options: [.new]) { [weak self] webView, _ in self?.publish(webView) },
                webView.observe(\.title, options: [.new]) { [weak self] webView, _ in self?.publish(webView) },
                webView.observe(\.canGoBack, options: [.new]) { [weak self] webView, _ in self?.publish(webView) },
                webView.observe(\.canGoForward, options: [.new]) { [weak self] webView, _ in self?.publish(webView) },
                webView.observe(\.isLoading, options: [.new]) { [weak self] webView, _ in self?.publish(webView) },
                webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in self?.publish(webView) }
            ]
        }

        private func publish(_ webView: WKWebView) {
            Task { @MainActor [weak self, weak webView] in
                guard let self, let webView else { return }
                self.controller?.refreshNavigationState(from: webView)
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            Task { @MainActor [weak self] in
                self?.controller?.readingStatus = "Loading…"
                self?.controller?.refreshNavigationState(from: webView)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor [weak self] in
                self?.controller?.readingStatus = "Ready"
                self?.controller?.refreshNavigationState(from: webView)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            publishFailure(error, webView: webView)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            publishFailure(error, webView: webView)
        }

        private func publishFailure(_ error: Error, webView: WKWebView) {
            Task { @MainActor [weak self] in
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled { return }
                self?.controller?.readingStatus = "Page failed to load: \(error.localizedDescription)"
                self?.controller?.refreshNavigationState(from: webView)
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url, let scheme = url.scheme?.lowercased() else {
                decisionHandler(.allow)
                return
            }

            if scheme == "http" || scheme == "https" || scheme == "about" {
                decisionHandler(.allow)
                return
            }

            decisionHandler(.cancel)
            Task { @MainActor in
                UIApplication.shared.open(url)
            }
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping () -> Void
        ) {
            presentAlert(title: webView.url?.host, message: message, actions: [
                ("OK", { completionHandler() })
            ])
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptConfirmPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (Bool) -> Void
        ) {
            presentAlert(title: webView.url?.host, message: message, actions: [
                ("Cancel", { completionHandler(false) }),
                ("OK", { completionHandler(true) })
            ])
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptTextInputPanelWithPrompt prompt: String,
            defaultText: String?,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (String?) -> Void
        ) {
            guard let presenter = topViewController() else {
                completionHandler(defaultText)
                return
            }

            let alert = UIAlertController(title: webView.url?.host, message: prompt, preferredStyle: .alert)
            alert.addTextField { $0.text = defaultText }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(nil) })
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(alert.textFields?.first?.text) })
            presenter.present(alert, animated: true)
        }

        @available(iOS 15.0, *)
        func webView(
            _ webView: WKWebView,
            requestMediaCapturePermissionFor origin: WKSecurityOrigin,
            initiatedByFrame frame: WKFrameInfo,
            type: WKMediaCaptureType,
            decisionHandler: @escaping (WKPermissionDecision) -> Void
        ) {
            decisionHandler(.prompt)
        }

        private func presentAlert(title: String?, message: String, actions: [(String, () -> Void)]) {
            guard let presenter = topViewController() else {
                actions.last?.1()
                return
            }
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            actions.forEach { title, action in
                alert.addAction(UIAlertAction(title: title, style: title == "Cancel" ? .cancel : .default) { _ in action() })
            }
            presenter.present(alert, animated: true)
        }

        private func topViewController() -> UIViewController? {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let root = scenes.flatMap(\.windows).first(where: { $0.isKeyWindow })?.rootViewController
            var top = root
            while let presented = top?.presentedViewController { top = presented }
            return top
        }
    }
}
