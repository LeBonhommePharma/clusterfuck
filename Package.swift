// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NaturalRemote",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10),
        .tvOS(.v17)
    ],
    products: [
        .library(name: "NaturalRemote", targets: ["NaturalRemote"]),
    ],
    dependencies: [
        .package(path: "../NATURaL/BonhommeCore"),
    ],
    targets: [
        .target(
            name: "NaturalRemote",
            dependencies: [
                .product(name: "BonhommeCore", package: "BonhommeCore"),
            ],
            path: "Sources/NaturalRemote"
        ),
        .testTarget(
            name: "NaturalRemoteTests",
            dependencies: ["NaturalRemote"],
            path: "Tests/NaturalRemoteTests"
        ),
    ]
)
