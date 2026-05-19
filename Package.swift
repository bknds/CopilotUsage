// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CopilotUsage",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "CopilotUsage",
            path: "Sources/CopilotUsage",
            resources: [.copy("Resources")]
        )
    ]
)
