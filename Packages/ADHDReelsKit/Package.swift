// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ADHDReelsKit",
    defaultLocalization: "ru",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "ADHDReelsKit", targets: ["ADHDReelsKit"])
    ],
    dependencies: [
        // Перевод треда языковой моделью. Считает Metal, поэтому работает
        // только на устройстве — в симуляторе переводит Apple Translation.
        .package(url: "https://github.com/ml-explore/mlx-swift-examples", .upToNextMinor(from: "2.29.1"))
    ],
    targets: [
        // Движок нейросетевой озвучки. Собранный xcframework кладёт
        // Scripts/fetch_tts.sh — в репозитории его нет, он на сотни мегабайт.
        .binaryTarget(name: "onnxruntime", path: "Frameworks/onnxruntime.xcframework"),
        .target(
            name: "CVoskTTS",
            dependencies: ["onnxruntime"],
            // Заголовки лежат в корне xcframework'а, а не внутри срезов, и сам Xcode
            // их не находит.
            cSettings: [.headerSearchPath("../../Frameworks/onnxruntime.xcframework/Headers")],
            // Движок написан на C++, а Swift тянет только libc.
            linkerSettings: [.linkedLibrary("c++")]
        ),
        .target(
            name: "ADHDReelsKit",
            dependencies: [
                "CVoskTTS",
                .product(name: "MLXLLM", package: "mlx-swift-examples"),
                .product(name: "MLXLMCommon", package: "mlx-swift-examples")
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
