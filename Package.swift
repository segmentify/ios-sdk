// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Segmentify",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "Segmentify",
            targets: ["Segmentify"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Segmentify",
            // The directory is lowercase in git; keep the path identical so the
            // package also resolves on case-sensitive file systems.
            path: "Sources/segmentify",
            exclude: [
                // Umbrella header of the legacy framework build; unused by SwiftPM.
                "Segmentify.h"
            ],
            resources: [
                .copy("version")
            ]
        ),
        .testTarget(
            name: "SegmentifyTests",
            dependencies: ["Segmentify"],
            path: "Tests"
        )
    ]
)
