// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumosMaxima",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "LumosMaxima"),
        .testTarget(
            name: "LumosMaximaTests",
            dependencies: ["LumosMaxima"]
        ),
    ]
)
