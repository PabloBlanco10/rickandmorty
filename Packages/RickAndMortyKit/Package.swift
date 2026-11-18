// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RickAndMortyKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Data", targets: ["Data"]),
        .library(name: "Presentation", targets: ["Presentation"])
    ],
    targets: [
        .target(name: "Domain", path: "Domain/Sources"),
        .target(name: "Data", dependencies: ["Domain"], path: "Data/Sources"),
        .target(name: "Presentation", dependencies: ["Domain"], path: "Presentation/Sources"),
        .testTarget(name: "DomainTests", dependencies: ["Domain"], path: "Domain/Tests"),
        .testTarget(name: "DataTests", dependencies: ["Data", "Domain"], path: "Data/Tests"),
        .testTarget(
            name: "PresentationTests",
            dependencies: ["Presentation", "Domain"],
            path: "Presentation/Tests"
        )
    ],
    swiftLanguageModes: [.v6]
)
