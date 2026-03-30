# Moonshine iOS/macOS Package

Swift Package for Moonshine Voice that supports both iOS and macOS.

## Building for macOS

The hosted `Moonshine.xcframework` artifacts have historically been missing
some required symbols in the `x86_64` slice. If you need to run on both Apple
Silicon and Intel Macs (or build a universal binary), build the macOS slices
from source and generate `swift/Moonshine.xcframework` locally.

### Build a universal macOS XCFramework (arm64 + x86_64)

```bash
cd swift
./scripts/build-macos-xcframework.sh
```

This script uses `cmake` to build `moonshine.framework` twice (once per arch)
and then uses `xcodebuild -create-xcframework` to combine them.

If `xcodebuild` errors with “active developer directory … CommandLineTools”,
run `xcode-select` to point at your full Xcode installation.

### Option 2: Use System Library (Current Workaround)

The package includes a system library target for macOS that links against `libmoonshine.dylib`. To use this:

1. Build the macOS dylib:
```bash
cd core
mkdir -p build
cd build
cmake ..
cmake --build . --config Release
# This creates libmoonshine.dylib in the build directory
```

2. Ensure the dylib is in a location where the linker can find it:
   - Copy to `/usr/local/lib/`, or
   - Set `DYLD_LIBRARY_PATH` to include the build directory, or
   - Update the linker settings in Package.swift to point to the correct path

## Using the Package

### iOS
```swift
import Moonshine

let transcriber = try Transcriber(modelPath: "...", modelArch: .base)
```

### macOS
```swift
import Moonshine

let transcriber = try Transcriber(modelPath: "...", modelArch: .base)
```

The package automatically uses the correct underlying library (framework for iOS, dylib for macOS).

