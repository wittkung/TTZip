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
        .library(
            name: "TTZipQuickLook",
            type: .dynamic,
            targets: ["TTZipQuickLook"]
        ),
        .library(
            name: "TTZipFinderSync",
            type: .dynamic,
            targets: ["TTZipFinderSync"]
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
        .target(
            name: "TTZipQuickLook",
            dependencies: ["TTZipCore"],
            exclude: ["Info.plist"]
        ),
        .target(
            name: "TTZipFinderSync",
            dependencies: ["TTZipCore"],
            exclude: ["Info.plist"]
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
                "TTZipCore"
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
