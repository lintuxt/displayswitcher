// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DisplaySwitcher",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "DDCKit", targets: ["DDCKit"]),
        .executable(name: "displayswitcher", targets: ["displayswitcher"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/lintuxt/swift-cli-kit", from: "0.1.0"),
    ],
    targets: [
        // C shim that loads the private IOAVService API via dlopen, so the
        // Swift code links cleanly with no undefined symbols.
        .target(name: "CIOAVService"),

        // The DDC/CI engine. No third-party dependencies.
        .target(
            name: "DDCKit",
            dependencies: ["CIOAVService"],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreGraphics"),
            ]
        ),

        // The CLI.
        .executableTarget(
            name: "displayswitcher",
            dependencies: [
                "DDCKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "CLIKit", package: "swift-cli-kit"),
            ]
        ),

        .testTarget(name: "DDCKitTests", dependencies: ["DDCKit"]),
    ]
)
