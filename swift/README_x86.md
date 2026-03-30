### What’s actually failing (and why x86_64 can’t link)

Your link errors (`Undefined symbols for architecture x86_64:
_moonshine_create_stream`, etc.) happen because the prebuilt
`Moonshine.xcframework` coming from `moonshine-swift` **v0.0.51** contains those
`moonshine_*` C-API symbols in the **arm64** slice, but **they’re missing in the
x86_64 slice**. So any Intel build (or “My Mac (Rosetta)” / universal build that
includes x86_64) will fail at link time.

That’s an upstream packaging issue: the x86_64 static library inside the xcframework simply doesn’t include `core/moonshine-c-api.cpp`’s exported symbols.

### What I changed in your repo
- Updated `examples/macos/MicTranscription/Package.swift` to **use the local Swift package** at `../../../swift`, because the hosted binary is broken for x86_64.
- Added `swift/scripts/build-macos-xcframework.sh` and updated `swift/README.md` with the intended universal-build flow.

### How to get a universal (arm64 + x86_64) build working
1. **Make sure `xcodebuild` is using full Xcode (not CommandLineTools)**

```bash
sudo xcode-select -s "/Applications/Xcode.app/Contents/Developer"
```

If git lfs isn’t installed:
```bash
git clone

brew install git-lfs
git lfs install
git lfs pull
git lfs checkout
```

2. **Install CMake** (your environment currently lacks it; the script fails with `cmake: command not found`)

- Via Homebrew:

```bash
brew install cmake
```

3. **Build a universal macOS `Moonshine.xcframework` from source**

```bash
cd /Users/guynicholson/moonshine/swift
./scripts/build-macos-xcframework.sh
```

4. **Build MicTranscription**
- SwiftPM:

```bash
cd /Users/guynicholson/moonshine/examples/macos/MicTranscription
swift package reset
rm -rf .build
swift build
```

- Xcode: regenerate the project (optional but recommended since `project.yml` expects the local package), then open and build:

```bash
cd /Users/guynicholson/moonshine/examples/macos/MicTranscription
xcodegen generate
open MicTranscription.xcodeproj
```

```bash
swift run MicTranscription \
  --model-path="${HOME}/moonshine/test-assets/tiny-en" \
  --model-arch="MOONSHINE_MODEL_ARCH_TINY"
```

### Notes

- Until `moonshine-swift` ships a fixed xcframework, **there’s no way to make Intel builds succeed using the hosted binary**; you must rebuild the macOS library slices yourself (or get an updated release that includes the C API symbols for x86_64).
