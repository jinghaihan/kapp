// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Kapp",
    platforms: [.macOS("15.2")],
    products: [.executable(name: "Kapp", targets: ["Kapp"])],
    targets: [
        .target(name: "KappRecording", path: "sources/recording"),
        .executableTarget(
            name: "Kapp",
            dependencies: ["KappRecording"],
            path: "sources/app",
            resources: [.process("assets")]
        ),
        .testTarget(
            name: "RecordingTests",
            dependencies: ["KappRecording"],
            path: "tests/recording-tests"
        ),
        .testTarget(
            name: "AppTests",
            dependencies: ["Kapp", "KappRecording"],
            path: "tests/app-tests"
        )
    ]
)
