// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "VaultSecurity",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
    ],
    products: [
        .library(
            name: "VaultSecurity",
            targets: ["VaultSecurity"]
        ),
    ],
    targets: [
        .target(
            name: "VaultSecurity"
        ),
        .testTarget(
            name: "VaultSecurityTests",
            dependencies: ["VaultSecurity"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
