// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DocDash",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "DocDash",
            path: "Sources/DocDash"
        )
    ]
)
