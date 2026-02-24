// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "appi18n",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "appi18n", targets: ["appi18n"]),
        .library(name: "AppI18nCore", targets: ["AppI18nCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.7.0")
    ],
    targets: [
        .target(
            name: "AppI18nCore",
            path: "Sources/AppI18nCore"
        ),
        .executableTarget(
            name: "appi18n",
            dependencies: [
                "AppI18nCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/appi18n"
        )
    ]
)
