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
            path: "Sources/Segmentify",
            exclude: [
                "Info.plist",
                "Example"
            ],
            resources: [
                .process("Resources"),
                .copy("version")
            ],
            publicHeadersPath: "include"
        ),
        .testTarget(
            name: "SegmentifyTests",
            dependencies: ["Segmentify"],
            path: "Tests",
            resources: [
                .copy("TestSupport/push-fixtures")
            ]
        )
    ]
)
