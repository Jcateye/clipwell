// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClipboardDrawer",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ClipboardDrawer", targets: ["ClipboardDrawer"])
    ],
    targets: [
        .executableTarget(
            name: "ClipboardDrawer",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
                .linkedFramework("Carbon"),
                .linkedFramework("Quartz")
            ]
        ),
        .testTarget(
            name: "ClipboardDrawerTests",
            dependencies: ["ClipboardDrawer"]
        )
    ]
)
