// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Puls",
    platforms: [.macOS("26.0")],
    targets: [
        .target(
            name: "CSystem",
            linkerSettings: [.linkedFramework("IOKit"), .linkedFramework("CoreFoundation")]
        ),
        .executableTarget(
            name: "Puls",
            dependencies: ["CSystem"],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("SystemConfiguration"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        .testTarget(
            name: "PulsTests",
            dependencies: ["Puls"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
