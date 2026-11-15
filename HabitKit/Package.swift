// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "HabitKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v26), .macOS(.v26), .watchOS(.v26)],
    products: [
        .library(name: "HabitKit", targets: ["HabitKit"]),
    ],
    targets: [
        .target(name: "HabitKit", resources: [.process("Resources")]),
        .testTarget(name: "HabitKitTests", dependencies: ["HabitKit"]),
    ]
)
