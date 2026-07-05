# ld64-build
Build script to compile `ld64` with fragile Objective-C runtime support.

> [!WARNING]
> This repository does not include any files from third-party projects. Dependencies are fetched from their repositories at build time.

### Requirements
- A Mac running macOS 12.0 Monterey or later
- Xcode 14 or newer
  - The Xcode toolchain must support C++20
  - Xcode 16 and older will produce a universal binary (both `x86_64` and `arm64`). Xcode 26 and above will produce only an `arm64` binary.

### How to compile
```
git clone <TBD/PATH>
cd ld64-build
chmod +x ./build.sh
./build.sh
```
The script also supports a non-interactive mode with the `--non-interactive` flag.

Once finished, you will notice that running the resulting `ld64-objc1` binary will have an issue when ran: `Library not loaded: @rpath/libtapi.dylib`. You will have to put the resulting binary either in an existing toolchain (I suggest you do **not** replace the regular `ld` but rather add on), or, for the most minimal setup, have a directory such as this:
```
ld
├── lib
│   ├── libswiftDemangle.dylib
│   └── libtapi.dylib
└── linker
    └── ld64-objc1
```
And put it in a secure area - I suggest the home folder on macOS, but anywhere that is secure and in a centralized location should work fine. You can get the `.dylib` files by copying them over from your Xcode toolchain:
```
cp $(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/lib/libswiftDemangle.dylib ld/lib/libswiftDemangle.dylib
cp $(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/lib/libtapi.dylib ld/lib/libtapi.dylib
```

#### License
This project's scripts and patches are licensed under [MIT](LICENSE). Third-party dependencies retain their respective licenses.

###### Copyright (c) 2026 Nightwind