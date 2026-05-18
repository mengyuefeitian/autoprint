// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AutoPrintMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AutoPrintMac", targets: ["AutoPrintMac"])
    ],
    targets: [
        .executableTarget(
            name: "AutoPrintMac",
            path: "AutoPrintMac"
        )
    ]
)
