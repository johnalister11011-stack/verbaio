// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VerbaIO",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "VerbaIO",
            path: "VerbaIO",
            exclude: ["Info.plist", "VerbaIO.entitlements"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Speech"),
                .linkedFramework("CoreGraphics"),
            ]
        )
    ]
)
