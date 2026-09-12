// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FloentlyShared",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "FloentlyShared", targets: ["FloentlyShared"])
    ],
    targets: [
        .target(
            name: "FloentlyShared",
            path: "Sources/FloentlyShared"
        )
    ]
)
