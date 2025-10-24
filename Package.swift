// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "SleeterServer",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.92.4"),
        .package(url: "https://github.com/vapor/fluent-mysql-driver.git", from: "4.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "SleeterServer",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "FluentMySQLDriver", package: "fluent-mysql-driver")
            ]
        )
    ]
)