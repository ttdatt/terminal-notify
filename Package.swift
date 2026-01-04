// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "terminal-notify",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "terminal-notify", targets: ["TerminalNotify"]),
        .executable(name: "terminal-notify-helper", targets: ["NotifyHelper"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0")
    ],
    targets: [
        .executableTarget(
            name: "TerminalNotify",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "NotifyShared"
            ],
            path: "Sources/TerminalNotify"
        ),
        .executableTarget(
            name: "NotifyHelper",
            dependencies: ["NotifyShared"],
            path: "Sources/NotifyHelper"
        ),
        .target(
            name: "NotifyShared",
            dependencies: [],
            path: "Sources/NotifyShared"
        )
    ]
)
