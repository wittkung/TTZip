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
            exclude: [
                "fast-lzma2",
                "lzfse",
                "snappy",
                "ttzip_threadpool.c"
            ],
            cSettings: [
                .headerSearchPath("include"),
                .headerSearchPath("fast-lzma2"),
                .headerSearchPath("lzfse"),
                .headerSearchPath("snappy"),
                .headerSearchPath("../../Vendor/include"),
                .headerSearchPath("../../Vendor/include/uchardet"),
                .unsafeFlags([
                    "-O3",
                    "-fvisibility=hidden",
                    "-Wall",
                    "-Wextra",
                    "-Wno-unused-function",
                    "-Wno-unused-parameter",
                    "-Wno-unused-variable",
                    "-Wno-sign-compare",
                    "-Wno-implicit-fallthrough",
                    "-Wno-missing-field-initializers",
                    "-Wformat=2"
                ])
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
            dependencies: ["TTZipCore"]
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
            dependencies: ["TTZipCore"],
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
