// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Vowrite",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Vowrite", targets: ["Vowrite"])
    ],
    targets: [
        .executableTarget(
            name: "Vowrite",
            path: ".",
            exclude: ["Package.swift", "Resources/Info.plist", "Resources/Vowrite.entitlements", "Vowrite.app"],
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
