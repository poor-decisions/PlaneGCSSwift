// swift-tools-version: 6.1
import PackageDescription

// Known limitation, tracked for later: these are Homebrew paths on this dev
// machine, not vendored headers. Eigen and Boost.Graph are both header-only,
// so vendoring them directly (like OCCTSwift ships a self-contained
// xcframework) is the right long-term fix — see draft/EXPERIMENTS.md,
// 2026-09-12 PlaneGCS native-compile spike entry.
let eigenInclude = "/opt/homebrew/opt/eigen/include/eigen3"
let boostInclude = "/opt/homebrew/opt/boost/include"

let package = Package(
    name: "PlaneGCSSwift",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "PlaneGCSSwift", targets: ["PlaneGCSSwift"])
    ],
    targets: [
        .target(
            name: "CPlaneGCS",
            cxxSettings: [
                .unsafeFlags(["-I", eigenInclude, "-I", boostInclude]),
            ]
        ),
        .target(
            name: "PlaneGCSBridge",
            dependencies: ["CPlaneGCS"],
            cxxSettings: [
                .unsafeFlags(["-I", eigenInclude, "-I", boostInclude]),
            ]
        ),
        .target(
            name: "PlaneGCSSwift",
            dependencies: ["PlaneGCSBridge"]
        ),
        .executableTarget(
            name: "PlaneGCSDemo",
            dependencies: ["PlaneGCSSwift"]
        ),
        .testTarget(
            name: "PlaneGCSSwiftTests",
            dependencies: ["PlaneGCSSwift"]
        ),
    ],
    cxxLanguageStandard: .cxx20
)
