// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CleanMD",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "CleanMD",
            path: "CleanMD",
            resources: [
                .copy("Resources")
            ]
        )
    ]
)
