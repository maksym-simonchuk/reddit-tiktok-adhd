// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ADHDReelsKit",
    defaultLocalization: "ru",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "ADHDReelsKit", targets: ["ADHDReelsKit"])
    ],
    targets: [
        .target(
            name: "ADHDReelsKit",
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
