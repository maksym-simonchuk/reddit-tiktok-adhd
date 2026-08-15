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
        // Движок нейросетевой озвучки. Собранные xcframework'и кладёт
        // Scripts/fetch_tts.sh — в репозитории их нет, они по сто мегабайт.
        .binaryTarget(name: "sherpa-onnx", path: "Frameworks/sherpa-onnx.xcframework"),
        .binaryTarget(name: "onnxruntime", path: "Frameworks/onnxruntime.xcframework"),
        .target(
            name: "CSherpaOnnx",
            dependencies: ["sherpa-onnx", "onnxruntime"],
            // Движок написан на C++, а Swift тянет только libc.
            linkerSettings: [.linkedLibrary("c++")]
        ),
        .target(
            name: "ADHDReelsKit",
            dependencies: ["CSherpaOnnx"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
