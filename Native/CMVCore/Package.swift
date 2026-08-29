// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CMVCore",
    platforms: [
        .macOS(.v15),
        .iOS(.v18)
    ],
    products: [
        .library(name: "CMVDomain", targets: ["CMVDomain"]),
        .library(name: "CMVLibrary", targets: ["CMVLibrary"]),
        .library(name: "CMVPlayback", targets: ["CMVPlayback"]),
        .library(name: "CMVAnalysis", targets: ["CMVAnalysis"]),
        .library(name: "CMVCache", targets: ["CMVCache"]),
        .library(name: "CMVThemes", targets: ["CMVThemes"])
    ],
    targets: [
        .target(name: "CMVDomain"),
        .target(name: "CMVLibrary", dependencies: ["CMVDomain"]),
        .target(name: "CMVPlayback", dependencies: ["CMVDomain"]),
        .target(name: "CMVAnalysis", dependencies: ["CMVDomain"]),
        .target(name: "CMVCache", dependencies: ["CMVDomain"]),
        .target(name: "CMVThemes", dependencies: ["CMVDomain"]),
        .testTarget(name: "CMVCoreTests", dependencies: [
            "CMVDomain", "CMVLibrary", "CMVAnalysis", "CMVCache"
        ])
    ]
)
