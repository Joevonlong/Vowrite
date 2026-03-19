// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "VowriteKit",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "VowriteKit", targets: ["VowriteKit"])
    ],
    targets: [
        .target(
            name: "VowriteKit",
            path: "Sources/VowriteKit",
            linkerSettings: [
                .linkedFramework("Security"),
                .linkedFramework("AuthenticationServices"),
                .linkedFramework("AVFoundation")
            ]
        )
    ]
)
