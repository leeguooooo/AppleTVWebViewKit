import Foundation
import SwiftUI

public struct WebBrowserView: View {
    private let url: URL
    private let showsDismissButton: Bool
    private let showsControls: Bool
    private let showsProgress: Bool
    private let configuration: WebViewConfiguration

    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = WebViewModel()

    public init(
        url: URL,
        showsDismissButton: Bool = true,
        showsControls: Bool = true,
        showsProgress: Bool = true,
        configuration: WebViewConfiguration = .init()
    ) {
        self.url = url
        self.showsDismissButton = showsDismissButton
        self.showsControls = showsControls
        self.showsProgress = showsProgress
        self.configuration = configuration
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if supportsWebKit && showsProgress && model.isLoading {
                    ProgressView(value: model.progress)
                        .progressViewStyle(.linear)
                        .tint(.blue)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }

                WebView(url: url, model: model, configuration: configuration)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                if supportsWebKit && showsControls {
                    controlBar
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
            }
            .navigationTitle(model.title.isEmpty ? "Browser" : model.title)
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                if showsDismissButton {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    private var supportsWebKit: Bool {
        #if canImport(WebKit)
        true
        #else
        PrivateWebKitSupport.isAvailable
        #endif
    }

    private var controlBar: some View {
        HStack(spacing: 16) {
            Button {
                model.goBack()
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!model.canGoBack)

            Button {
                model.goForward()
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(!model.canGoForward)

            Button {
                model.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
            }

            Spacer()

            Text(displayURL)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var displayURL: String {
        let current = model.currentURL ?? url
        return current.host ?? current.absoluteString
    }
}
