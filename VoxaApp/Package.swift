// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Voxa",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Voxa", targets: ["Voxa"])
    ],
    targets: [
        .executableTarget(
            name: "Voxa",
            path: ".",
            exclude: ["Package.swift", "Resources/Info.plist", "Resources/Voxa.entitlements", "Voxa.app"],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ],
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Security")
            ]
        )
    ]
)
