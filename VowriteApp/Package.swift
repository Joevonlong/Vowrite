// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Vowrite",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Vowrite", targets: ["Vowrite"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "Vowrite",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: ".",
            exclude: ["Package.swift", "Resources/Info.plist", "Resources/Vowrite.entitlements", "Resources/AppIcon-source.png", "Vowrite.app", "build.sh", "scripts"],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ],
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Security"),
                .linkedFramework("AuthenticationServices")
            ]
        )
    ]
)
