// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "mac2jb-gui",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "mac2jb_gui",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
    ]
)
