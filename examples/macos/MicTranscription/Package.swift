// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "MicTranscription",
    platforms: [.macOS(.v13)],
    dependencies: [
        // Use the locally-built Swift package so we can build a universal (arm64+x86_64)
        // `Moonshine.xcframework` from source. The prebuilt `moonshine-swift` v0.0.51
        // artifact is missing the `moonshine_*` C API symbols in its x86_64 slice.
        .package(path: "../../../swift"),

        // If you only need arm64, you can switch back to the hosted binary:
        // .package(url: "https://github.com/moonshine-ai/moonshine-swift.git", from: "0.0.51")
    ],
    targets: [
        .executableTarget(
            name: "MicTranscription",
            dependencies: [
                .product(name: "MoonshineVoice", package: "swift")
            ]
        )
    ]
)
