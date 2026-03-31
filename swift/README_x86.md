The following steps were assisted by Cursor chat.

Tested on
* Mac mini 2018 (Intel i7, 32GB)
* macOS Sequoia 15.7.4
* XCode 16.4

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

2. **Install CMake and codegen and git-lfs** (your environment currently lacks these tools)

- Via Homebrew:

```bash
brew install cmake xcodegen git-lfs

git lfs install
```

3. **Build a universal macOS `Moonshine.xcframework` from source in a branch in this fork**

```bash
cd
git clone git@github.com:guynich/moonshine.git

cd moonshine
git fetch origin build_x86
git checkout build_x86

cd ${HOME}/moonshine/swift
./scripts/build-macos-xcframework.sh
```

4. **Build MicTranscription**
- SwiftPM:

```bash
cd ${HOME}/moonshine/examples/macos/MicTranscription
swift package reset
rm -rf .build
swift build
```

- Xcode: regenerate the project (optional but recommended since `project.yml` expects the local package), then open and build:

```bash
cd ${HOME}/moonshine/examples/macos/MicTranscription
xcodegen generate
open MicTranscription.xcodeproj
```
The last command fails - the model path is not found.  Instead run this `swift` command specifying the model location
and architecture.
```bash
swift run MicTranscription \
  --model-path="${HOME}/moonshine/test-assets/tiny-en" \
  --model-arch="MOONSHINE_MODEL_ARCH_TINY"
```

Example run.  Connect a USB microphone before running
this command.
```console
$ swift run MicTranscription --model-path="${HOME}/moonshine/test-assets/tiny-en" --model-arch="MOONSHINE_MODEL_ARCH_TINY"
Building for debugging...
[1/1] Write swift-version--58304C5D6DBC2206.txt
Build of product 'MicTranscription' complete! (0.28s)
Listening to the microphone, press Ctrl+C to stop...
3.17s: Line started: Test one.
3.17s: Line text changed: Test one.
3.17s: Line text changed: Test one, two, three, three.
3.17s: Line text changed: Test one, two, three, four, five, five,
3.17s: Line text changed: Test one, two, three, four, five.
3.17s: Line completed: Test one, two, three, four, five.
```
* I'm not sure why the timestamp was "3.17" for all the lines.

### Notes

- Until `moonshine-swift` ships a fixed xcframework, **there’s no way to make Intel builds succeed using the hosted binary**; you must rebuild the macOS library slices yourself (or get an updated release that includes the C API symbols for x86_64).

#### Streaming

We can try the streaming model with this command.
```bash
swift run MicTranscription \
--model-path="${HOME}/moonshine/test-assets/tiny-streaming-en" \
--model-arch="MOONSHINE_MODEL_ARCH_TINY_STREAMING"
```

However the call fails.  The console states model ORT assets are missing.
```console
$ swift run MicTranscription --model-path="${HOME}/moonshine/test-assets/tiny-streaming-en"  --model-arch="MOONSHINE_MODEL_ARCH_TINY_STREAMING"
Building for debugging...
[1/1] Write swift-version--58304C5D6DBC2206.txt
Build of product 'MicTranscription' complete! (0.34s)
Thread 0x70000ab12000:moonshine-c-api.cpp:183:moonshine_load_transcriber_from_files(): Failed to load transcriber: Required encoder model file does not exist at path '/Users/guynicholson/moonshine/test-assets/tiny-streaming-en/encoder_model.ort'

MicTranscription/main.swift:38: Fatal error: 'try!' expression unexpectedly raised an error: MoonshineVoice.MoonshineError.custom(message: "Failed to load transcriber: Unknown error", code: -1)

💣 Program crashed: Illegal instruction at 0x00007ff8210936f8

Thread 1 crashed:

0 0x00007ff8210936f8 _assertionFailure(_:_:file:line:flags:) + 264 in libswiftCore.dylib
1 0x00007ff8210eda64 swift_unexpectedError + 788 in libswiftCore.dylib
2 main() + 5725 in MicTranscription at /Users/guynicholson/moonshine/examples/macos/MicTranscription/Sources/MicTranscription/main.swift:38:31

    36│     }
    37│
    38│     let micTranscriber = try! MicTranscriber(modelPath: modelPath!, modelArch: modelArch!)
      │                               ▲
    39│     defer { micTranscriber.close() }
    40│

Backtrace took 1.22s
```
