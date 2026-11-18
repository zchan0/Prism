// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Prism",
    platforms: [.macOS(.v14)],
    targets: [
        // The shell: everything a tool needs, and nothing any particular tool knows.
        .target(name: "PrismKit"),

        // One module per tool. A tool only exposes the type that conforms to `Tool`; the rest stays internal to it,
        // so two tools cannot reach into each other by accident.
        .target(name: "LumosTool", dependencies: ["PrismKit"]),
        .target(name: "VitalsTool", dependencies: ["PrismKit"]),
        .target(name: "PortkeyTool", dependencies: ["PrismKit"]),

        .executableTarget(
            name: "Prism",
            dependencies: ["PrismKit", "LumosTool", "VitalsTool", "PortkeyTool"]
        ),
        .testTarget(
            name: "PrismTests",
            dependencies: ["PrismKit", "LumosTool", "VitalsTool", "PortkeyTool"]
        ),
    ]
)
