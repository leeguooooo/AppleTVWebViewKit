#if canImport(WebKit)
import WebKit
public typealias WebViewMediaTypes = WKAudiovisualMediaTypes
#else
import Foundation

public struct WebViewMediaTypes: OptionSet {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let audio = WebViewMediaTypes(rawValue: 1 << 0)
    public static let video = WebViewMediaTypes(rawValue: 1 << 1)
    public static let all: WebViewMediaTypes = [.audio, .video]
}
#endif

public struct WebViewConfiguration {
    public var allowsInlineMediaPlayback: Bool
    public var mediaTypesRequiringUserActionForPlayback: WebViewMediaTypes
    public var customUserAgent: String?
    public var additionalHeaders: [String: String]

    public init(
        allowsInlineMediaPlayback: Bool = true,
        mediaTypesRequiringUserActionForPlayback: WebViewMediaTypes = [],
        customUserAgent: String? = nil,
        additionalHeaders: [String: String] = [:]
    ) {
        self.allowsInlineMediaPlayback = allowsInlineMediaPlayback
        self.mediaTypesRequiringUserActionForPlayback = mediaTypesRequiringUserActionForPlayback
        self.customUserAgent = customUserAgent
        self.additionalHeaders = additionalHeaders
    }
}
