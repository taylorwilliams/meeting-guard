// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MeetingGuard",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "MeetingGuard", targets: ["MeetingGuard"])],
    targets: [
        .target(name: "MeetingGuardCore"),
        .executableTarget(name: "MeetingGuard", dependencies: ["MeetingGuardCore"]),
        .testTarget(name: "MeetingGuardCoreTests", dependencies: ["MeetingGuardCore"])
    ]
)
