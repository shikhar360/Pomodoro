// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Pomodoro",
    platforms: [.macOS(.v15)],
    targets: [
        // Rules and data logic with no SwiftUI, so tests run without the app.
        .target(name: "PomodoroKit"),
        .executableTarget(
            name: "Pomodoro",
            dependencies: ["PomodoroKit"],
        ),
        .testTarget(name: "PomodoroKitTests", dependencies: ["PomodoroKit"]),
    ]
)
