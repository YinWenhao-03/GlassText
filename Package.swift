// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "GlassText", platforms: [.macOS(.v13)], products: [.executable(name: "GlassText", targets: ["GlassText"])], targets: [.executableTarget(name: "GlassText")])
