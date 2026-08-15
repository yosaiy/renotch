// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Renotch",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Renotch", targets: ["Renotch"]),
        .executable(name: "RenotchBrowserBridge", targets: ["RenotchBrowserBridge"])
    ],
    targets: [
        .executableTarget(
            name: "Renotch",
            path: "Sources/Renotch",
            resources: [
                .copy("Resources/TrayIconTemplate.png")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .executableTarget(
            name: "RenotchBrowserBridge",
            path: "BrowserBridge",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
