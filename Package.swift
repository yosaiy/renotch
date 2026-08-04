// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "VirtualNotch",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "VirtualNotch", targets: ["VirtualNotch"]),
        .executable(name: "VirtualNotchBrowserBridge", targets: ["VirtualNotchBrowserBridge"])
    ],
    targets: [
        .executableTarget(
            name: "VirtualNotch",
            path: "Sources/VirtualNotch",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .executableTarget(
            name: "VirtualNotchBrowserBridge",
            path: "BrowserBridge",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
