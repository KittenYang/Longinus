// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Longinus",
    platforms: [.iOS(.v10)],
    products: [
        .library(
            name: "Longinus",
            targets: ["Longinus"]),
        .library(
            name: "LonginusSwiftUI",
            targets: ["LonginusSwiftUI"]),
    ],
    targets: [
        .target(
            name: "Longinus",
            path: "Sources",
            exclude: ["SwiftUI"]),
        .target(
            name: "LonginusSwiftUI",
            dependencies: ["Longinus"],
            path: "Sources",
            sources: ["SwiftUI"]
        )

    ]
)
