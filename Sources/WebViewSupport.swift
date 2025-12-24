import Foundation

public enum WebViewSupport {
    public static var isAvailable: Bool {
        #if canImport(WebKit)
        return true
        #else
        return PrivateWebKitSupport.isAvailable
        #endif
    }
}
