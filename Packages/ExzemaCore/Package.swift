// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ExzemaCore",
    platforms: [.iOS("27.0"), .macOS("26.0")],
    products: [
        .library(name: "ExzemaCore", targets: ["ExzemaCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.11.1"),
    ],
    targets: [
        .target(
            name: "ExzemaCore",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")]
        ),
        .testTarget(
            name: "ExzemaCoreTests",
            dependencies: ["ExzemaCore", .product(name: "GRDB", package: "GRDB.swift")],
            resources: [.copy("Stores")]
        ),
    ]
)
