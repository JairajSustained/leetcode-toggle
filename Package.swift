// swift-tools-version: 6.0
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
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
