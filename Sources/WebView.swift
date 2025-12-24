import Foundation
import SwiftUI
#if canImport(WebKit)
import WebKit

public struct WebView: UIViewRepresentable {
    @ObservedObject private var model: WebViewModel
    private let url: URL
    private let configuration: WebViewConfiguration

    public init(url: URL, model: WebViewModel, configuration: WebViewConfiguration = .init()) {
        self.url = url
        self.model = model
        self.configuration = configuration
    }

    public func makeUIView(context: Context) -> WKWebView {
        let webConfig = WKWebViewConfiguration()
        webConfig.allowsInlineMediaPlayback = configuration.allowsInlineMediaPlayback
        webConfig.mediaTypesRequiringUserActionForPlayback = configuration.mediaTypesRequiringUserActionForPlayback

        let webView = WKWebView(frame: .zero, configuration: webConfig)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = configuration.customUserAgent

        context.coordinator.observe(webView)
        model.attach(webView)

        var request = URLRequest(url: url)
        configuration.additionalHeaders.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        webView.load(request)
        context.coordinator.recordRequestedLoad(url: url, headers: configuration.additionalHeaders)

        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.loadIfNeeded(
            url: url,
            headers: configuration.additionalHeaders,
            in: uiView
        )
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    public final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private let model: WebViewModel
        private var progressObserver: NSKeyValueObservation?
        private var lastRequestedURL: URL?
        private var lastRequestedHeaders: [String: String] = [:]

        init(model: WebViewModel) {
            self.model = model
        }

        func observe(_ webView: WKWebView) {
            progressObserver = webView.observe(\.estimatedProgress, options: [.new]) { [weak model] webView, _ in
                guard let model else { return }
                let progress = webView.estimatedProgress
                if Thread.isMainThread {
                    model.progress = progress
                } else {
                    DispatchQueue.main.async {
                        model.progress = progress
                    }
                }
            }
        }

        func recordRequestedLoad(url: URL, headers: [String: String]) {
            lastRequestedURL = url
            lastRequestedHeaders = headers
        }

        func loadIfNeeded(url: URL, headers: [String: String], in webView: WKWebView) {
            guard url != lastRequestedURL || headers != lastRequestedHeaders else { return }
            lastRequestedURL = url
            lastRequestedHeaders = headers

            var request = URLRequest(url: url)
            headers.forEach { key, value in
                request.setValue(value, forHTTPHeaderField: key)
            }
            webView.load(request)
        }

        public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            model.setProgress(0)
            model.update(from: webView)
        }

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            model.update(from: webView)
            model.setProgress(1)
        }

        public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            model.update(from: webView)
        }

        public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            model.update(from: webView)
        }

        public func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}
#else
import UIKit
import Darwin

public struct WebView: UIViewRepresentable {
    @ObservedObject private var model: WebViewModel
    private let url: URL
    private let configuration: WebViewConfiguration

    public init(url: URL, model: WebViewModel, configuration: WebViewConfiguration = .init()) {
        self.url = url
        self.model = model
        self.configuration = configuration
    }

    public func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear

        guard let webView = PrivateWebKitSupport.makeWebView(
            url: url,
            configuration: configuration,
            model: model,
            delegate: context.coordinator.delegate
        ) else {
            let placeholder = PrivateWebKitSupport.unavailableView(for: url)
            container.addSubview(placeholder)
            placeholder.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                placeholder.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                placeholder.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                placeholder.topAnchor.constraint(equalTo: container.topAnchor),
                placeholder.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
            return container
        }

        container.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        context.coordinator.recordRequestedLoad(url: url, headers: configuration.additionalHeaders)
        return container
    }

    public func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.loadIfNeeded(url: url, headers: configuration.additionalHeaders)
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    public final class Coordinator: NSObject {
        let delegate: NavigationDelegateProxy
        private let model: WebViewModel
        private var lastRequestedURL: URL?
        private var lastRequestedHeaders: [String: String] = [:]

        init(model: WebViewModel) {
            self.model = model
            delegate = NavigationDelegateProxy(model: model)
        }

        func recordRequestedLoad(url: URL, headers: [String: String]) {
            lastRequestedURL = url
            lastRequestedHeaders = headers
        }

        func loadIfNeeded(url: URL, headers: [String: String]) {
            guard url != lastRequestedURL || headers != lastRequestedHeaders else { return }
            lastRequestedURL = url
            lastRequestedHeaders = headers
            model.load(url, headers: headers)
        }
    }
}

final class NavigationDelegateProxy: NSObject {
    private weak var model: WebViewModel?
    private weak var webView: NSObject?

    init(model: WebViewModel) {
        self.model = model
    }

    func attachWebView(_ webView: NSObject) {
        self.webView = webView
        model?.attach(webView)
    }

    @objc(webView:didStartProvisionalNavigation:)
    func webView(_ webView: AnyObject, didStartProvisionalNavigation navigation: AnyObject) {
        model?.setLoading(true)
        model?.setProgress(0)
        if let webView = webView as? NSObject {
            model?.update(from: webView)
        }
    }

    @objc(webView:didFinishNavigation:)
    func webView(_ webView: AnyObject, didFinishNavigation navigation: AnyObject) {
        model?.setLoading(false)
        if let webView = webView as? NSObject {
            model?.update(from: webView)
            model?.setProgress(1)
        }
    }

    @objc(webView:didFailNavigation:withError:)
    func webView(_ webView: AnyObject, didFailNavigation navigation: AnyObject, withError error: NSError) {
        model?.setLoading(false)
        if let webView = webView as? NSObject {
            model?.update(from: webView)
        }
    }

    @objc(webView:didFailProvisionalNavigation:withError:)
    func webView(_ webView: AnyObject, didFailProvisionalNavigation navigation: AnyObject, withError error: NSError) {
        model?.setLoading(false)
        if let webView = webView as? NSObject {
            model?.update(from: webView)
        }
    }
}

enum PrivateWebKitSupport {
    private static var didAttemptLoad = false
    private enum ObjcRuntime {
        static let handle: UnsafeMutableRawPointer? = dlopen(nil, RTLD_NOW)
        static let symbol: UnsafeMutableRawPointer? = handle.flatMap { dlsym($0, "objc_msgSend") }

        static func cast<T>(to type: T.Type) -> T? {
            guard let symbol else { return nil }
            return unsafeBitCast(symbol, to: type)
        }
    }

    static var isAvailable: Bool {
        loadIfNeeded()
        return NSClassFromString("WKWebView") != nil
    }

    static func makeWebView(
        url: URL,
        configuration: WebViewConfiguration,
        model: WebViewModel,
        delegate: NavigationDelegateProxy
    ) -> UIView? {
        guard isAvailable else { return nil }
        guard let webViewObject = instantiateWebView(configuration: configuration) else { return nil }
        guard let webViewView = webViewObject as? UIView else { return nil }

        delegate.attachWebView(webViewObject)
        setDelegate(delegate, on: webViewObject)
        applySettings(to: webViewObject, configuration: configuration)
        load(url: url, configuration: configuration, on: webViewObject)

        return webViewView
    }

    static func unavailableView(for url: URL) -> UIView {
        let container = UIView()
        let title = UILabel()
        let subtitle = UILabel()

        title.text = "WebKit not available"
        title.font = .systemFont(ofSize: 22, weight: .semibold)
        title.textAlignment = .center
        title.textColor = .white

        subtitle.text = url.absoluteString
        subtitle.font = .systemFont(ofSize: 14)
        subtitle.textAlignment = .center
        subtitle.textColor = UIColor.white.withAlphaComponent(0.7)
        subtitle.numberOfLines = 3

        let stack = UIStackView(arrangedSubviews: [title, subtitle])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -20),
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }

    private static func loadIfNeeded() {
        guard !didAttemptLoad else { return }
        didAttemptLoad = true

        let candidates = [
            "/System/Library/Frameworks/WebKit.framework/WebKit",
            "/System/Library/PrivateFrameworks/WebKit.framework/WebKit"
        ]

        for path in candidates {
            if dlopen(path, RTLD_NOW) != nil {
                break
            }
        }
    }

    private static func instantiateWebView(configuration: WebViewConfiguration) -> NSObject? {
        guard
            let config = createConfiguration(configuration),
            let webViewClass = NSClassFromString("WKWebView") as? NSObject.Type
        else {
            return nil
        }

        typealias MsgSendAlloc = @convention(c) (AnyObject, Selector) -> Unmanaged<AnyObject>
        typealias MsgSendInit = @convention(c) (AnyObject, Selector, CGRect, AnyObject) -> Unmanaged<AnyObject>

        guard
            let msgSendAlloc = ObjcRuntime.cast(to: MsgSendAlloc.self),
            let msgSendInit = ObjcRuntime.cast(to: MsgSendInit.self)
        else {
            return nil
        }

        let allocSelector = NSSelectorFromString("alloc")
        let allocObject = msgSendAlloc(webViewClass, allocSelector).takeUnretainedValue()
        let initSelector = NSSelectorFromString("initWithFrame:configuration:")
        let webView = msgSendInit(allocObject, initSelector, .zero, config).takeRetainedValue()
        return webView as? NSObject
    }

    private static func createConfiguration(_ configuration: WebViewConfiguration) -> NSObject? {
        guard let configClass = NSClassFromString("WKWebViewConfiguration") as? NSObject.Type else {
            return nil
        }

        let config = configClass.init()
        setIfResponds(config, selector: "setAllowsInlineMediaPlayback:", value: configuration.allowsInlineMediaPlayback)
        setIfResponds(
            config,
            selector: "setMediaTypesRequiringUserActionForPlayback:",
            value: NSNumber(value: configuration.mediaTypesRequiringUserActionForPlayback.rawValue)
        )
        return config
    }

    private static func load(url: URL, configuration: WebViewConfiguration, on webView: NSObject) {
        let request = NSMutableURLRequest(url: url)
        configuration.additionalHeaders.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        let selector = NSSelectorFromString("loadRequest:")
        if webView.responds(to: selector) {
            webView.perform(selector, with: request)
        }
    }

    private static func setDelegate(_ delegate: NavigationDelegateProxy, on webView: NSObject) {
        setIfResponds(webView, selector: "setNavigationDelegate:", value: delegate)
    }

    private static func applySettings(to webView: NSObject, configuration: WebViewConfiguration) {
        setIfResponds(webView, selector: "setAllowsBackForwardNavigationGestures:", value: true)
        if let userAgent = configuration.customUserAgent {
            setIfResponds(webView, selector: "setCustomUserAgent:", value: userAgent)
        }
    }

    private static func setIfResponds(_ object: NSObject, selector: String, value: Any) {
        let sel = NSSelectorFromString(selector)
        guard object.responds(to: sel) else { return }
        let key = keyPath(fromSetter: selector)
        object.setValue(value, forKey: key)
    }

    private static func keyPath(fromSetter selector: String) -> String {
        guard selector.hasPrefix("set"), selector.hasSuffix(":") else {
            return selector
        }
        let start = selector.index(selector.startIndex, offsetBy: 3)
        let end = selector.index(before: selector.endIndex)
        let rawKey = String(selector[start..<end])
        guard let first = rawKey.first else { return rawKey }
        let lowercasedFirst = String(first).lowercased()
        return lowercasedFirst + rawKey.dropFirst()
    }
}
#endif
