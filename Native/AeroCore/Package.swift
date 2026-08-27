// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AeroCore",
    platforms: [
        .macOS(.v15),
        .iOS(.v18)
    ],
    products: [
        .library(name: "AeroDomain", targets: ["AeroDomain"]),
        .library(name: "AeroLibrary", targets: ["AeroLibrary"]),
        .library(name: "AeroPlayback", targets: ["AeroPlayback"]),
        .library(name: "AeroAnalysis", targets: ["AeroAnalysis"]),
        .library(name: "AeroCache", targets: ["AeroCache"]),
        .library(name: "AeroThemes", targets: ["AeroThemes"])
    ],
    targets: [
        .target(name: "AeroDomain"),
        .target(name: "AeroLibrary", dependencies: ["AeroDomain"]),
        .target(name: "AeroPlayback", dependencies: ["AeroDomain"]),
        .target(name: "AeroAnalysis", dependencies: ["AeroDomain"]),
        .target(name: "AeroCache", dependencies: ["AeroDomain"]),
        .target(name: "AeroThemes", dependencies: ["AeroDomain"]),
        .testTarget(name: "AeroCoreTests", dependencies: [
            "AeroDomain", "AeroLibrary", "AeroAnalysis", "AeroCache"
        ])
    ]
)
