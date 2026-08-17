# Android Rust smoke harness

This consumer is deliberately small: it builds a real Rust executable against
the cel-bridge crate and evaluates 1 + 1 == 2. The Android emulator job builds
it for armv7, arm64, and x86_64; it runs the x86_64 executable after placing
the matching Go shared library beside it.

From the repository root, with an Android NDK installed:

    export CEL_BRIDGE_BUILD_FROM_SOURCE=1
    export CARGO_TARGET_X86_64_LINUX_ANDROID_LINKER=$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin/x86_64-linux-android21-clang
    cargo build --manifest-path sdk/rust/tests-platform/android/Cargo.toml \
      --target x86_64-linux-android

The runner must package libcel_bridge.so for the same ABI and set
LD_LIBRARY_PATH when launching the executable. A different ABI library must
never be used as a fallback.
