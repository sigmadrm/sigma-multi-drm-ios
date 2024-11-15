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
            publicHeadersPath: "Classes/SigmaMultiDRM.h",
            cSettings: [
                .headerSearchPath("Classes")
            ]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
