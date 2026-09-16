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
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "AutoPrintMac",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "AutoPrintMac",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
            ]
        ),
        .testTarget(
            name: "AutoPrintMacTests",
            dependencies: ["AutoPrintMac"],
            path: "AutoPrintMacTests"
        )
    ]
)
