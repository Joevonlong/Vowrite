// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "VowriteMac",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "VowriteMac", targets: ["VowriteMac"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
        .package(path: "../VowriteKit")
    ],
    targets: [
        .executableTarget(
            name: "VowriteMac",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "VowriteKit", package: "VowriteKit")
            ],
            path: "Sources",
            exclude: [],
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
