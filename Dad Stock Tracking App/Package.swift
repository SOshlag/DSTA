// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DadStockAlerts",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "DadStockAlerts", targets: ["DadStockAlerts"])],
    targets: [
        .executableTarget(name: "DadStockAlerts", path: "Sources/DadStockAlerts"),
        .testTarget(name: "DadStockAlertsTests", dependencies: ["DadStockAlerts"], path: "Tests/DadStockAlertsTests")
    ]
)
