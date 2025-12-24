// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LeeguooWebViewKit",
    platforms: [.iOS(.v17), .tvOS(.v17)],
    products: [
        .library(
            name: "LeeguooWebViewKit",
            targets: ["LeeguooWebViewKit"]
        )
    ],
    targets: [
        .target(
            name: "LeeguooWebViewKit",
            path: "Sources"
        )
    ]
)
