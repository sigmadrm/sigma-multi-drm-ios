// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "SigmaMultiDRM",
    platforms: [
        .iOS(.v8)
    ],
    products: [
        .library(
            name: "SigmaMultiDRM",
            targets: ["SigmaMultiDRM"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SigmaMultiDRM",
            dependencies: [],
            path: "Classes",
            publicHeadersPath: "Classes",
            cSettings: [
                .headerSearchPath("Classes"),
                .define("SWIFT_PACKAGE")
            ]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
