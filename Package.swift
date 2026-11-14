// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Sift",
    platforms: [.macOS(.v14)],
    dependencies: [
        // Installs new versions from inside the app. scripts/build-app.sh copies the framework into Sift.app.
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.6.4")
    ],
    targets: [
        .executableTarget(
            name: "Sift",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/Sift",
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .testTarget(name: "SiftTests", dependencies: ["Sift"], path: "Tests/SiftTests")
    ]
)
