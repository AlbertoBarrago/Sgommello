// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Sgommello",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Sgommello",
            path: "Sources/Sgommello",
            linkerSettings: [
                // Embed Info.plist into the bare executable: TCC requires
                // NSCameraUsageDescription to grant webcam access, and an SPM
                // binary has no bundle to carry it.
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Info.plist"
                ])
            ]
        )
    ]
)
