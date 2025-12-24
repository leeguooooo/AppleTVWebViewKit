// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AppleTVWebViewKit",
    platforms: [.iOS(.v17), .tvOS(.v17)],
    products: [
        .library(
            name: "AppleTVWebViewKit",
            targets: ["AppleTVWebViewKit"]
        )
    ],
    targets: [
        .target(
            name: "AppleTVWebViewKit",
            path: "Sources"
        )
    ]
)
