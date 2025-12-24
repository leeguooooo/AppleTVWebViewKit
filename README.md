# AppleTVWebViewKit

SwiftUI-friendly WebView wrapper.

- iOS/iPadOS: uses WKWebView.
- tvOS: attempts to load private WebKit at runtime. If unavailable, renders a placeholder.

Note: private WebKit is not App Store safe. Use at your own risk.

## Availability check

```swift
if WebViewSupport.isAvailable {
    // Safe to attempt WebView on tvOS.
}
```

## Usage

```swift
import AppleTVWebViewKit

struct ContentView: View {
    var body: some View {
        WebBrowserView(url: URL(string: "https://example.com")!)
    }
}
```

## Configuration

```swift
WebBrowserView(
    url: URL(string: "https://example.com")!,
    configuration: WebViewConfiguration(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserActionForPlayback: []
    )
)
```
