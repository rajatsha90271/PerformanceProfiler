// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PerformanceProfiler",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "PerformanceProfiler", targets: ["PerformanceProfiler"]),
        .library(name: "ProfilerUI", targets: ["ProfilerUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-atomics.git", from: "1.2.0"),
    ],
    targets: [
        .target(
            name: "ProfilerCore",
            dependencies: [
                .product(name: "Atomics", package: "swift-atomics"),
            ],
            path: "Sources/ProfilerCore"
        ),
        .target(
            name: "PerformanceProfiler",
            dependencies: ["ProfilerCore"],
            path: "Sources/PerformanceProfiler"
        ),
        .target(
            name: "ProfilerUI",
            dependencies: ["PerformanceProfiler"],
            path: "Sources/ProfilerUI"
        ),
        .testTarget(
            name: "ProfilerCoreTests",
            dependencies: [
                "ProfilerCore",
                .product(name: "Atomics", package: "swift-atomics"),
            ],
            path: "Tests/ProfilerCoreTests"
        ),
        .testTarget(
            name: "PerformanceProfilerTests",
            dependencies: ["PerformanceProfiler"],
            path: "Tests/PerformanceProfilerTests"
        ),
    ]
)
