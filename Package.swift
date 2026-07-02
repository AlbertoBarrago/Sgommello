// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Sgommello",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.3")
    ],
    targets: [
        .executableTarget(
            name: "Sgommello",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/Sgommello",
            exclude: ["AGENTS.md"],
            linkerSettings: [
                // Embed Info.plist into the bare executable: TCC requires
                // NSCameraUsageDescription to grant webcam access, and an SPM
                // binary has no bundle to carry it.
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Info.plist",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../Frameworks"
                ])
            ]
        )
    ]
)
