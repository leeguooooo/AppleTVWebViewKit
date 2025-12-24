import Foundation
import SwiftUI

#if canImport(WebKit)
import WebKit

public final class WebViewModel: ObservableObject {
    @Published public private(set) var canGoBack = false
    @Published public private(set) var canGoForward = false
    @Published public private(set) var title = ""
    @Published public private(set) var currentURL: URL?
    @Published public private(set) var isLoading = false
    @Published public private(set) var progress: Double = 0

    weak var webView: WKWebView?

    public init() {}

    public func attach(_ webView: WKWebView) {
        self.webView = webView
        update(from: webView)
    }

    public func update(from webView: WKWebView) {
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        title = webView.title ?? ""
        currentURL = webView.url
        isLoading = webView.isLoading
    }

    public func goBack() {
        webView?.goBack()
    }

    public func goForward() {
        webView?.goForward()
    }

    public func reload() {
        webView?.reload()
    }

    public func load(_ url: URL, headers: [String: String] = [:]) {
        var request = URLRequest(url: url)
        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        webView?.load(request)
    }

    func setProgress(_ value: Double) {
        progress = value
    }

    func setLoading(_ value: Bool) {
        isLoading = value
    }
}
#else
public final class WebViewModel: ObservableObject {
    @Published public private(set) var canGoBack = false
    @Published public private(set) var canGoForward = false
    @Published public private(set) var title = ""
    @Published public private(set) var currentURL: URL?
    @Published public private(set) var isLoading = false
    @Published public private(set) var progress: Double = 0

    weak var webView: NSObject?

    public init() {}

    public func attach(_ webView: NSObject) {
        self.webView = webView
        update(from: webView)
    }

    public func update(from webView: NSObject) {
        canGoBack = boolValue(forKey: "canGoBack", in: webView)
        canGoForward = boolValue(forKey: "canGoForward", in: webView)
        title = stringValue(forKey: "title", in: webView)
        currentURL = urlValue(forKey: "URL", in: webView) ?? urlValue(forKey: "url", in: webView)
        isLoading = boolValue(forKey: "loading", in: webView) || boolValue(forKey: "isLoading", in: webView)

        if let progressValue = numberValue(forKey: "estimatedProgress", in: webView) {
            progress = progressValue
        }
    }

    public func goBack() {
        webView?.perform(NSSelectorFromString("goBack"))
    }

    public func goForward() {
        webView?.perform(NSSelectorFromString("goForward"))
    }

    public func reload() {
        webView?.perform(NSSelectorFromString("reload"))
    }

    public func load(_ url: URL, headers: [String: String] = [:]) {
        let request = NSMutableURLRequest(url: url)
        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        webView?.perform(NSSelectorFromString("loadRequest:"), with: request)
    }

    func setProgress(_ value: Double) {
        progress = value
    }

    func setLoading(_ value: Bool) {
        isLoading = value
    }

    private func boolValue(forKey key: String, in webView: NSObject) -> Bool {
        guard let value = safeValue(forKey: key, in: webView) else { return false }
        if let boolValue = value as? Bool {
            return boolValue
        }
        if let numberValue = value as? NSNumber {
            return numberValue.boolValue
        }
        return false
    }

    private func stringValue(forKey key: String, in webView: NSObject) -> String {
        guard let value = safeValue(forKey: key, in: webView) else { return "" }
        if let stringValue = value as? String {
            return stringValue
        }
        return ""
    }

    private func numberValue(forKey key: String, in webView: NSObject) -> Double? {
        guard let value = safeValue(forKey: key, in: webView) else { return nil }
        if let doubleValue = value as? Double {
            return doubleValue
        }
        if let numberValue = value as? NSNumber {
            return numberValue.doubleValue
        }
        return nil
    }

    private func urlValue(forKey key: String, in webView: NSObject) -> URL? {
        guard let value = safeValue(forKey: key, in: webView) else { return nil }
        if let urlValue = value as? URL {
            return urlValue
        }
        if let urlValue = value as? NSURL {
            return urlValue as URL
        }
        return nil
    }

    private func safeValue(forKey key: String, in webView: NSObject) -> Any? {
        guard hasSelector(forKey: key, in: webView) else { return nil }
        return webView.value(forKey: key)
    }

    private func hasSelector(forKey key: String, in webView: NSObject) -> Bool {
        let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKey.isEmpty else { return false }

        let capitalizedKey = normalizedKey.prefix(1).uppercased() + normalizedKey.dropFirst()
        let selectors = [
            normalizedKey,
            "is" + capitalizedKey,
            "get" + capitalizedKey
        ]

        return selectors.contains { webView.responds(to: NSSelectorFromString($0)) }
    }
}
#endif
