// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Data-Collection",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "Data-Collection", targets: ["Data-Collection"])
    ],
    dependencies: [
        .package(url: "https://github.com/NordicSemiconductor/IOS-BLE-Library.git", from: "0.3.3")
    ],
    targets: [
        .target(
            name: "Data-Collection",
            dependencies: [
                .product(name: "iOS-BLE-Library", package: "IOS-BLE-Library")
            ],
            path: "Data-Collection",
            exclude: ["Info.plist", "Data_Collection.entitlements"],
            resources: [.process("Resources")]
        )
    ]
)
