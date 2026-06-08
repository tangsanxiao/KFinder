// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "XFinder",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "XFinder", targets: ["XFinder"])
    ],
    targets: [
        .executableTarget(
            name: "XFinder",
            path: "Sources/XFinder"
        ),
        .testTarget(
            name: "XFinderTests",
            dependencies: ["XFinder"],
            path: "Tests/XFinderTests"
        )
    ]
)
