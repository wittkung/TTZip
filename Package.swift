// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TTZip",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "TTZipCore",
            targets: ["TTZipCore"]
        ),
        .executable(
            name: "TTZipApp",
            targets: ["TTZipApp"]
        ),
        .executable(
            name: "ttzip-cli",
            targets: ["TTZipCLI"]
        ),
        .executable(
            name: "ttzip-bench",
            targets: ["TTZipBench"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.0")
    ],
    targets: [
        .binaryTarget(
            name: "TTZipVendor",
            path: "Vendor/TTZipVendor.xcframework"
        ),
        .target(
            name: "CTTZipBridge",
            dependencies: ["TTZipVendor"],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include")
            ],
            linkerSettings: [
                .linkedLibrary("bz2"),
                .linkedLibrary("iconv"),
                .linkedLibrary("xml2"),
                .linkedLibrary("expat"),
                .linkedLibrary("c++"),
                .linkedLibrary("compression"),
                .linkedFramework("Security")
            ]
        ),
        .target(
            name: "TTZipCore",
            dependencies: ["CTTZipBridge"],
            swiftSettings: [
                .unsafeFlags(["-no-whole-module-optimization", "-enable-batch-mode"])
            ]
        ),
        .executableTarget(
            name: "TTZipApp",
            dependencies: [
                "TTZipCore",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            exclude: ["Info.plist", "TTZip.entitlements", "TTZip-Direct.entitlements"],
            resources: [
                .copy("Resources/AppIcon.icns"),
                .process("Resources/Assets.xcassets")
            ]
        ),
        .executableTarget(
            name: "TTZipCLI",
            dependencies: [
                "TTZipCore",
                "CTTZipBridge"
            ]
        ),
        .executableTarget(
            name: "TTZipBench",
            dependencies: [
                "TTZipCore",
                "CTTZipBridge"
            ],
            swiftSettings: [
                .unsafeFlags(["-no-whole-module-optimization", "-enable-batch-mode"])
            ]
        ),
        .testTarget(
            name: "TTZipTests",
            dependencies: [
                "TTZipCore",
                "TTZipCLI"
            ],
            resources: [
                .copy("Fixtures")
            ],
            swiftSettings: [
                .unsafeFlags(["-no-whole-module-optimization", "-enable-batch-mode"])
            ]
        ),
        .testTarget(
            name: "TTZipAppTests",
            dependencies: ["TTZipCore", "TTZipApp"]
        )
    ]
)
