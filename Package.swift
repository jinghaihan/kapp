// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Kapp",
    defaultLocalization: "en",
    platforms: [.macOS("15.2")],
    products: [.executable(name: "Kapp", targets: ["Kapp"])],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1")
    ],
    targets: [
        .target(name: "KappLocalization", path: "sources/localization", resources: [.process("resources")]),
        .target(name: "KappRecording", dependencies: ["KappLocalization"], path: "sources/recording"),
        .executableTarget(
            name: "Kapp",
            dependencies: ["KappRecording", "KappLocalization", .product(name: "Sparkle", package: "Sparkle")],
            path: "sources/app",
            resources: [.process("assets")],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(
            name: "RecordingTests",
            dependencies: ["KappRecording"],
            path: "tests/recording-tests"
        ),
        .testTarget(
            name: "AppTests",
            dependencies: ["Kapp", "KappRecording", "KappLocalization"],
            path: "tests/app-tests"
        ),
        .testTarget(
            name: "LocalizationTests",
            dependencies: ["KappLocalization"],
            path: "tests/localization-tests"
        )
    ]
)
