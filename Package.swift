// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OPDownloader",
    platforms: [
        .iOS(.v16),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "OPDownloader",
            targets: [
                "OPDownloader",
                "OPDownloaderUI",
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/mzeeshanid/MZDownloadManager.git", branch: "master"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "OPDownloader",
            dependencies: [
                "MZDownloadManager",
            ]
        ),
        .target(
            name: "OPDownloaderUI",
            dependencies: [
                
            ],
            path: "Sources/OPDownloaderUI"
        ),
        .testTarget(
            name: "OPDownloaderTests",
            dependencies: [
                "OPDownloader",
            ]
        ),
    ]
)
