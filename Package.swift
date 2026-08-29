// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "leetcode-toggle",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "leetcode-toggle",
            resources: [
                .copy("Resources/leetcode.svg")
            ]
            // Swift 5 language mode is the default for swift-tools 5.x.
        )
    ]
)
