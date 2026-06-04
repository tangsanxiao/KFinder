// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "KFinder",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "KFinder", targets: ["KFinder"])
    ],
    targets: [
        .executableTarget(
            name: "KFinder",
            path: "Sources/KFinder"
        ),
        .testTarget(
            name: "KFinderTests",
            dependencies: ["KFinder"],
            path: "Tests/KFinderTests"
        )
    ]
)
