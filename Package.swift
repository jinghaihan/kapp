// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Kapp",
    platforms: [.macOS("15.2")],
    products: [.executable(name: "Kapp", targets: ["Kapp"])],
    targets: [
        .target(name: "KappRecording", path: "Sources/Recording"),
        .executableTarget(
            name: "Kapp",
            dependencies: ["KappRecording"],
            path: "Sources/App"
        ),
        .testTarget(
            name: "RecordingTests",
            dependencies: ["KappRecording"],
            path: "Tests/RecordingTests"
        ),
        .testTarget(
            name: "AppTests",
            dependencies: ["Kapp"],
            path: "Tests/AppTests"
        )
    ]
)
