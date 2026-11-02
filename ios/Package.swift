// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "WardrobeCore", platforms: [.macOS(.v14), .iOS(.v17)], products: [.library(name: "WardrobeCore", targets: ["WardrobeCore"])], targets: [.target(name: "WardrobeCore", path: "Wardrobe/Core"), .testTarget(name: "WardrobeCoreTests", dependencies: ["WardrobeCore"], path: "Tests/WardrobeCoreTests")])
