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
            name: "SimaMultiDRMObjC",
            dependencies: [],
            path: "ObjCSources",
            exclude: ["SwiftSources"]
        )
        .target(
            name: "SigmaMultiDRM",
            dependencies: ["SimaMultiDRMObjC"]
            path: "SwiftSources" 
        ),
    ],
    swiftLanguageVersions: [.v5]
)
