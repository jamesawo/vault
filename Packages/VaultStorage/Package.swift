// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "VaultStorage",
    platforms: [
        .iOS(.v16),
        .macOS(.v10_15),
    ],
    products: [
        .library(
            name: "VaultStorage",
            targets: ["VaultStorage"]
        ),
    ],
    dependencies: [
        .package(path: "../VaultSecurity"),
    ],
    targets: [
        .target(
            name: "VaultStorage",
            dependencies: [
                .product(name: "VaultSecurity", package: "VaultSecurity"),
            ]
        ),
        .testTarget(
            name: "VaultStorageTests",
            dependencies: ["VaultStorage"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
