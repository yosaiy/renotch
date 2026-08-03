// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "VirtualNotch",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "VirtualNotch", targets: ["VirtualNotch"])
    ],
    targets: [
        .executableTarget(
            name: "VirtualNotch",
            path: "Sources/VirtualNotch",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
