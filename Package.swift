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
            cSettings: [
                .headerSearchPath("include"),
                .headerSearchPath("fast-lzma2"),
                .headerSearchPath("lzfse"),
                .headerSearchPath("../../Vendor/include"),
                .headerSearchPath("../../Vendor/include/uchardet"),
                .unsafeFlags(["-O3"])
            ],
            linkerSettings: [
                .linkedLibrary("bz2"),
                .linkedLibrary("iconv"),
                .linkedLibrary("xml2"),
                .linkedLibrary("expat"),
                .linkedLibrary("c++")
            ]
        ),
        .target(
            name: "TTZipCore",
            dependencies: ["CTTZipBridge"]
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
            dependencies: ["TTZipCore"]
        ),
        .testTarget(
            name: "TTZipTests",
            dependencies: ["TTZipCore", "TTZipApp"],
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)
