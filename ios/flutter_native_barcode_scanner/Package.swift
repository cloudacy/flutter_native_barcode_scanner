// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "flutter_native_barcode_scanner",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "flutter-native-barcode-scanner", targets: ["flutter_native_barcode_scanner"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "flutter_native_barcode_scanner",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
            ]
        )
    ]
)
